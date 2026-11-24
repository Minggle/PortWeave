package core

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/tunnel"
	"golang.org/x/net/proxy"
)

func TestPortRoutingWire(t *testing.T) {
	if os.Getenv("FLCLASH_PORT_TEST_CHILD") != "1" {
		ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestPortRoutingWire$", "-test.v")
		cmd.Env = append(os.Environ(), "FLCLASH_PORT_TEST_CHILD=1")
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("isolated Core test: %v\n%s", err, output)
		}
		return
	}

	newExit := func(marker string) *httptest.Server {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/stream" {
				_, _ = io.WriteString(w, marker)
				return
			}
			ticker := time.NewTicker(40 * time.Millisecond)
			defer ticker.Stop()
			for {
				_, _ = fmt.Fprintln(w, marker)
				w.(http.Flusher).Flush()
				select {
				case <-ticker.C:
				case <-r.Context().Done():
					return
				}
			}
		}))
		t.Cleanup(server.Close)
		return server
	}
	newProxy := func(target *httptest.Server) *httptest.Server {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method != http.MethodConnect {
				http.Error(w, "CONNECT required", http.StatusBadRequest)
				return
			}
			remote, err := net.Dial("tcp", target.Listener.Addr().String())
			if err != nil {
				http.Error(w, err.Error(), 502)
				return
			}
			client, rw, err := w.(http.Hijacker).Hijack()
			if err != nil {
				_ = remote.Close()
				return
			}
			defer client.Close()
			defer remote.Close()
			_, _ = rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n")
			_ = rw.Flush()
			go func() { _, _ = io.Copy(remote, rw); _ = remote.Close() }()
			_, _ = io.Copy(client, remote)
		}))
		t.Cleanup(server.Close)
		return server
	}
	a := newProxy(newExit("A"))
	b := newProxy(newExit("B"))
	c := newProxy(newExit("C"))
	payload := func(upstream *httptest.Server, name string) string {
		port := upstream.Listener.Addr().(*net.TCPAddr).Port
		return fmt.Sprintf("proxies:\n  - {name: %q, type: http, server: 127.0.0.1, port: %d}\n", name, port)
	}
	home := t.TempDir()
	t.Cleanup(func() { _ = cachefile.Cache().Close() })
	if err := handleInit(&InitParams{HomeDir: home}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(handleShutdown)
	paths := []string{filepath.Join(home, "a.yaml"), filepath.Join(home, "b.yaml")}
	for i, data := range []string{payload(a, "US Same"), payload(b, "US Same")} {
		if err := os.WriteFile(paths[i], []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	ports := make([]int, 6)
	for i := range ports {
		listener, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		ports[i] = listener.Addr().(*net.TCPAddr).Port
		_ = listener.Close()
	}
	config := fmt.Sprintf(`mixed-port: 0
mode: rule
log-level: silent
dns: {enable: false}
tun: {enable: false}
proxy-providers:
  flclash_ports_source_11:
    type: file
    path: %q
    override: {additional-prefix: '[ports:11] '}
  flclash_ports_source_22:
    type: file
    path: %q
    override: {additional-prefix: '[ports:22] '}
proxy-groups:
  - {name: flclash_ports_group_1, type: select, use: [flclash_ports_source_11], filter: '^\[ports:11\] US Same$', empty-fallback: REJECT}
  - {name: flclash_ports_group_2, type: select, use: [flclash_ports_source_22], filter: '^\[ports:22\] US Same$', empty-fallback: REJECT}
  - {name: flclash_ports_group_3, type: url-test, use: [flclash_ports_source_11], filter: '(?i)^\[ports:11\] .*(?:us).*$', empty-fallback: REJECT, url: 'http://127.0.0.1:1/health', interval: 300, lazy: true}
  - {name: aggregate, type: url-test, use: [flclash_ports_source_11, flclash_ports_source_22], filter: '(?i)^\[ports:(11|22)\] .*(?:us).*$', empty-fallback: REJECT, url: 'http://127.0.0.1:1/health', interval: 300, lazy: true}
sub-rules:
  policy_11: ['DOMAIN,policy-b.test,flclash_ports_group_2', 'MATCH,flclash_ports_group_1']
  policy_22: ['MATCH,flclash_ports_group_2']
listeners:
  - {name: flclash_ports_in_1, type: mixed, listen: 127.0.0.1, port: %d, proxy: flclash_ports_group_1, udp: false, users: []}
  - {name: flclash_ports_in_2, type: mixed, listen: 127.0.0.1, port: %d, proxy: flclash_ports_group_2, udp: false, users: []}
  - {name: flclash_ports_in_3, type: mixed, listen: 127.0.0.1, port: %d, proxy: flclash_ports_group_3, udp: false, users: []}
  - {name: original_11, type: mixed, listen: 127.0.0.1, port: %d, rule: policy_11, udp: false, users: []}
  - {name: original_22, type: mixed, listen: 127.0.0.1, port: %d, rule: policy_22, udp: false, users: []}
  - {name: combined, type: mixed, listen: 127.0.0.1, port: %d, proxy: aggregate, udp: false, users: []}
rules: ['MATCH,REJECT']
`, paths[0], paths[1], ports[0], ports[1], ports[2], ports[3], ports[4], ports[5])
	if err := os.WriteFile(runningConfigPath(), []byte(config), 0600); err != nil {
		t.Fatal(err)
	}
	if err := handleSetupConfig(&SetupParams{}); err != nil {
		t.Fatal(err)
	}
	handleStartListener()
	deadline := time.Now().Add(5 * time.Second)
	for {
		providers := tunnel.ProvidersSnapshot()
		if providers["flclash_ports_source_11"].Count() > 0 && providers["flclash_ports_source_22"].Count() > 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("providers did not initialize")
		}
		time.Sleep(10 * time.Millisecond)
	}
	client := func(port int, socks bool) *http.Client {
		transport := &http.Transport{DisableKeepAlives: true}
		if socks {
			dialer, err := proxy.SOCKS5("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)), nil, proxy.Direct)
			if err != nil {
				t.Fatal(err)
			}
			transport.DialContext = func(_ context.Context, network, address string) (net.Conn, error) {
				return dialer.Dial(network, address)
			}
		} else {
			u, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port))
			transport.Proxy = http.ProxyURL(u)
		}
		t.Cleanup(transport.CloseIdleConnections)
		return &http.Client{Transport: transport, Timeout: 4 * time.Second}
	}
	request := func(client *http.Client) (string, error) {
		response, err := client.Get("http://127.0.0.1:1/who")
		if err != nil {
			return "", err
		}
		defer response.Body.Close()
		body, err := io.ReadAll(response.Body)
		if response.StatusCode != 200 {
			return string(body), fmt.Errorf("HTTP %d", response.StatusCode)
		}
		return string(body), err
	}
	assertExit := func(port int, marker string) {
		t.Helper()
		for _, socks := range []bool{false, true} {
			if body, err := request(client(port, socks)); err != nil || body != marker {
				t.Logf("groups: %+v", handleGetProxies())
				for name, provider := range tunnel.ProvidersSnapshot() {
					for _, node := range provider.Proxies() {
						t.Logf("provider %s node %q", name, node.Name())
					}
				}
				t.Fatalf("port %d socks=%v: body=%q err=%v, want %s", port, socks, body, err, marker)
			}
		}
	}
	assertExit(ports[0], "A")
	assertExit(ports[1], "B")
	assertExit(ports[2], "A")
	assertExit(ports[3], "A")
	assertExit(ports[4], "B")
	for _, socks := range []bool{false, true} {
		response, err := client(ports[3], socks).Get("http://policy-b.test/policy")
		if err != nil {
			t.Fatal(err)
		}
		body, err := io.ReadAll(response.Body)
		_ = response.Body.Close()
		if err != nil || string(body) != "B" {
			t.Fatalf("original rules were not followed: %q %v", body, err)
		}
	}
	if body, err := request(client(ports[5], false)); err != nil || (body != "A" && body != "B") {
		t.Fatalf("aggregate returned %q: %v", body, err)
	}
	stream, err := client(ports[1], false).Get("http://127.0.0.1:1/stream")
	if err != nil {
		t.Fatal(err)
	}
	defer stream.Body.Close()
	reader := bufio.NewReader(stream.Body)
	if line, err := reader.ReadString('\n'); err != nil || line != "B\n" {
		t.Fatalf("initial stream: %q %v", line, err)
	}
	if err := handleSideLoadExternalProvider(&SideLoadParams{Name: "flclash_ports_source_11", Data: payload(c, "US Same")}); err != nil {
		t.Fatal(err)
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "flclash_ports_group_3"}); result.Message != "" {
		t.Fatal(result.Message)
	}
	assertExit(ports[0], "C")
	assertExit(ports[2], "C")
	assertExit(ports[1], "B")
	for range 3 {
		if line, err := reader.ReadString('\n'); err != nil || line != "B\n" {
			t.Fatalf("unrelated stream interrupted: %q %v", line, err)
		}
	}
	if err := handleSideLoadExternalProvider(&SideLoadParams{Name: "flclash_ports_source_11", Data: payload(c, "JP New")}); err != nil {
		t.Fatal(err)
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "flclash_ports_group_3"}); result.Message != "" {
		t.Fatal(result.Message)
	}
	for _, port := range []int{ports[0], ports[2]} {
		if body, err := request(client(port, false)); err == nil && (body == "A" || body == "B" || body == "C") {
			t.Fatalf("missing fixed/region node at port %d still returned %q; groups: %+v", port, body, handleGetProxies())
		}
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "aggregate"}); result.Message != "" {
		t.Fatal(result.Message)
	}
	assertExit(ports[5], "B")
	if err := handleSideLoadExternalProvider(&SideLoadParams{Name: "flclash_ports_source_22", Data: "proxies: []"}); err == nil {
		t.Fatal("empty provider accepted")
	}
	assertExit(ports[1], "B")
	if err := handleSideLoadExternalProvider(&SideLoadParams{Name: "flclash_ports_source_22", Data: payload(b, "JP Only")}); err != nil {
		t.Fatal(err)
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "aggregate"}); result.Message != "" {
		t.Fatal(result.Message)
	}
	if body, err := request(client(ports[5], false)); err == nil {
		t.Fatalf("aggregate without matching nodes did not reject: %q", body)
	}

	mixedListener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	mixedPort := mixedListener.Addr().(*net.TCPAddr).Port
	_ = mixedListener.Close()
	coexistConfig := fmt.Sprintf(`mixed-port: %d
mode: rule
log-level: silent
dns: {enable: false}
tun: {enable: false}
proxy-providers:
  flclash_ports_source_11:
    type: file
    path: %q
    override: {additional-prefix: '[ports:11] '}
  flclash_ports_source_22:
    type: file
    path: %q
    override: {additional-prefix: '[ports:22] '}
proxy-groups:
  - {name: flclash_ports_group_1, type: select, use: [flclash_ports_source_11], filter: '^\[ports:11\] JP New$', empty-fallback: REJECT}
  - {name: flclash_ports_group_2, type: select, use: [flclash_ports_source_22], filter: '^\[ports:22\] JP Only$', empty-fallback: REJECT}
sub-rules:
  policy_22: ['MATCH,flclash_ports_group_2']
listeners:
  - {name: original_22, type: mixed, listen: 127.0.0.1, port: %d, rule: policy_22, udp: false, users: []}
rules:
  - DOMAIN,policy-b.test,flclash_ports_group_2
  - MATCH,flclash_ports_group_1
`, mixedPort, paths[0], paths[1], ports[4])
	if err := os.WriteFile(runningConfigPath(), []byte(coexistConfig), 0600); err != nil {
		t.Fatal(err)
	}
	if err := handleSetupConfig(&SetupParams{}); err != nil {
		t.Fatal(err)
	}
	handleStartListener()
	deadline = time.Now().Add(5 * time.Second)
	for {
		providers := tunnel.ProvidersSnapshot()
		if providers["flclash_ports_source_11"].Count() > 0 && providers["flclash_ports_source_22"].Count() > 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("coexistence providers did not initialize")
		}
		time.Sleep(10 * time.Millisecond)
	}
	assertExit(mixedPort, "C")
	assertExit(ports[4], "B")
	for _, socks := range []bool{false, true} {
		response, err := client(mixedPort, socks).Get("http://policy-b.test/policy")
		if err != nil {
			t.Fatal(err)
		}
		body, err := io.ReadAll(response.Body)
		_ = response.Body.Close()
		if err != nil || string(body) != "B" {
			t.Fatalf("coexistence top-level rules were not followed: %q %v", body, err)
		}
	}
}
