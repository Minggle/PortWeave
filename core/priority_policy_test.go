package core

import (
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
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/tunnel"
)

func TestPriorityPolicyWire(t *testing.T) {
	if os.Getenv("PORTWEAVE_PRIORITY_TEST_CHILD") != "1" {
		ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestPriorityPolicyWire$", "-test.v")
		cmd.Env = append(os.Environ(), "PORTWEAVE_PRIORITY_TEST_CHILD=1")
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("isolated priority test: %v\n%s", err, out)
		}
		return
	}
	proxy := func(marker string, enabled *atomic.Bool, delay time.Duration) *httptest.Server {
		exit := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { time.Sleep(delay); _, _ = io.WriteString(w, marker) }))
		t.Cleanup(exit.Close)
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !enabled.Load() {
				http.Error(w, "unavailable", 503)
				return
			}
			remote, err := net.Dial("tcp", exit.Listener.Addr().String())
			if err != nil {
				http.Error(w, "failed", 502)
				return
			}
			client, rw, err := w.(http.Hijacker).Hijack()
			if err != nil {
				remote.Close()
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
	var mainOn, firstOn, secondOn atomic.Bool
	mainOn.Store(true)
	firstOn.Store(true)
	secondOn.Store(true)
	primary := proxy("SELF", &mainOn, 15*time.Millisecond)
	first := proxy("FIRST", &firstOn, 0)
	second := proxy("SECOND", &secondOn, 0)
	home := t.TempDir()
	t.Cleanup(func() { _ = cachefile.Cache().Close() })
	if err := handleInit(&InitParams{HomeDir: home}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(handleShutdown)
	payload := func(server *httptest.Server) string {
		return fmt.Sprintf("proxies: [{name: US, type: http, server: 127.0.0.1, port: %d}]\n", server.Listener.Addr().(*net.TCPAddr).Port)
	}
	for name, server := range map[string]*httptest.Server{"first": first, "second": second} {
		if err := os.WriteFile(filepath.Join(home, name+".yaml"), []byte(payload(server)), 0600); err != nil {
			t.Fatal(err)
		}
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	listener.Close()
	ports := make([]int, 2)
	for i := range ports {
		reserved, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		ports[i] = reserved.Addr().(*net.TCPAddr).Port
		reserved.Close()
	}
	const probe = "http://probe.test/health"
	config := fmt.Sprintf(`mixed-port: %d
mode: rule
log-level: silent
dns: {enable: false}
tun: {enable: false}
proxies: [{name: Self, type: http, server: 127.0.0.1, port: %d}]
proxy-providers:
  First: {type: file, path: %q, override: {additional-prefix: 'A '}}
  Second: {type: file, path: %q, override: {additional-prefix: 'B '}}
proxy-groups:
  - {name: Taiwan, type: fallback, proxies: [Self], url: '%s', interval: 3600, lazy: true}
  - {name: TierA, type: url-test, use: [First], filter: 'US', empty-fallback: REJECT, url: '%s', interval: 3600, lazy: true}
  - {name: TierB, type: url-test, use: [Second], empty-fallback: REJECT, url: '%s', interval: 3600, lazy: true}
  - {name: Video, type: fallback, proxies: [Taiwan, TierA, TierB], url: '%s', interval: 3600, lazy: true}
rules: ['DOMAIN,video.test,Video','MATCH,REJECT']
sub-rules:
  aggregate_port: ['DOMAIN,video.test,Video','MATCH,REJECT']
listeners:
  - {name: aggregate, type: mixed, listen: 127.0.0.1, port: %d, rule: aggregate_port, udp: false, users: []}
  - {name: provider, type: mixed, listen: 127.0.0.1, port: %d, proxy: TierA, udp: false, users: []}
`, port, primary.Listener.Addr().(*net.TCPAddr).Port, filepath.Join(home, "first.yaml"), filepath.Join(home, "second.yaml"), probe, probe, probe, probe, ports[0], ports[1])
	if err := os.WriteFile(runningConfigPath(), []byte(config), 0600); err != nil {
		t.Fatal(err)
	}
	if err := handleSetupConfig(&SetupParams{}); err != nil {
		t.Fatal(err)
	}
	handleStartListener()
	deadline := time.Now().Add(5 * time.Second)
	for tunnel.ProvidersSnapshot()["First"].Count() == 0 || tunnel.ProvidersSnapshot()["Second"].Count() == 0 {
		if time.Now().After(deadline) {
			t.Fatal("providers did not initialize")
		}
		time.Sleep(10 * time.Millisecond)
	}
	check := func() {
		for _, provider := range []string{"First", "Second"} {
			for _, node := range tunnel.ProvidersSnapshot()[provider].Proxies() {
				ctx, cancel := context.WithTimeout(context.Background(), time.Second)
				_, _ = node.URLTest(ctx, probe, nil)
				cancel()
			}
		}
		for _, name := range []string{"Self", "Taiwan", "TierA", "TierB"} {
			p := lookupProxy(name)
			if p == nil {
				t.Fatalf("missing %s", name)
			}
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			_, _ = p.URLTest(ctx, probe, nil)
			cancel()
		}
	}
	u, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port))
	transport := &http.Transport{Proxy: http.ProxyURL(u), DisableKeepAlives: true}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 2 * time.Second}
	request := func() (string, error) {
		r, e := client.Get("http://video.test/data")
		if e != nil {
			return "", e
		}
		defer r.Body.Close()
		b, e := io.ReadAll(r.Body)
		if r.StatusCode != 200 {
			return string(b), fmt.Errorf("status %d", r.StatusCode)
		}
		return string(b), e
	}
	aggregateURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", ports[0]))
	aggregateTransport := &http.Transport{Proxy: http.ProxyURL(aggregateURL), DisableKeepAlives: true}
	defer aggregateTransport.CloseIdleConnections()
	aggregateClient := &http.Client{Transport: aggregateTransport, Timeout: 2 * time.Second}
	expect := func(want string) {
		t.Helper()
		deadline := time.Now().Add(5 * time.Second)
		for {
			check()
			body, e := request()
			if e == nil && body == want {
				response, err := aggregateClient.Get("http://video.test/data")
				if err == nil {
					got, readErr := io.ReadAll(response.Body)
					response.Body.Close()
					if readErr == nil && string(got) == want {
						return
					}
				}
			}
			if time.Now().After(deadline) {
				t.Fatalf("got %q %v, want %s", body, e, want)
			}
			time.Sleep(20 * time.Millisecond)
		}
	}
	expect("SELF")
	providerURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", ports[1]))
	providerTransport := &http.Transport{Proxy: http.ProxyURL(providerURL), DisableKeepAlives: true}
	defer providerTransport.CloseIdleConnections()
	providerClient := &http.Client{Transport: providerTransport, Timeout: 2 * time.Second}
	response, err := providerClient.Get("http://video.test/data")
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil || string(body) != "FIRST" {
		t.Fatalf("provider port should bypass aggregate priorities: %q %v", body, err)
	}
	mainOn.Store(false)
	expect("FIRST")
	firstOn.Store(false)
	expect("SECOND")
	firstOn.Store(true)
	expect("FIRST")
	if err := handleSideLoadExternalProvider(&SideLoadParams{Name: "First", Data: strings.ReplaceAll(payload(first), "name: US", "name: JP")}); err != nil {
		t.Fatal(err)
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "TierA"}); result.Message != "" {
		t.Fatal(result.Message)
	}
	expect("SECOND")
	if err := handleSideLoadExternalProvider(&SideLoadParams{Name: "First", Data: strings.ReplaceAll(payload(first), "name: US", "name: US New")}); err != nil {
		t.Fatal(err)
	}
	if result := handleChangeProxy(&ChangeProxyParams{GroupName: "TierA"}); result.Message != "" {
		t.Fatal(result.Message)
	}
	expect("FIRST")
	mainOn.Store(true)
	expect("SELF")
	mainOn.Store(false)
	firstOn.Store(false)
	secondOn.Store(false)
	check()
	if body, e := request(); e == nil {
		t.Fatalf("all failed but traffic succeeded: %q", body)
	}
}
