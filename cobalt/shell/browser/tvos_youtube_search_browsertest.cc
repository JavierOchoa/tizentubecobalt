// Copyright 2026 The Cobalt Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <memory>
#include <string>

#include "base/functional/bind.h"
#include "cobalt/base/generated_resources_types.h"
#include "cobalt/shell/embedded_resources/tvos_javascript.h"
#include "cobalt/testing/browser_tests/browser/test_shell.h"
#include "cobalt/testing/browser_tests/content_browser_test.h"
#include "cobalt/testing/browser_tests/content_browser_test_utils.h"
#include "content/public/test/browser_test.h"
#include "content/public/test/browser_test_utils.h"
#include "content/public/test/test_navigation_observer.h"
#include "net/dns/mock_host_resolver.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "url/gurl.h"

namespace content {
namespace {

constexpr char kInputId[] = "cobalt-tvos-youtube-search-input";

std::unique_ptr<net::test_server::HttpResponse> HandleYouTubeRequest(
    const net::test_server::HttpRequest& request) {
  if (!request.GetURL().PathForRequest().starts_with("/tv")) {
    return nullptr;
  }
  auto response = std::make_unique<net::test_server::BasicHttpResponse>();
  response->set_code(net::HTTP_OK);
  response->set_content_type("text/html");
  response->set_content(
      "<!doctype html><button id=previous autofocus>Previous</button>");
  return response;
}

class TvOSYouTubeSearchBrowserTest : public ContentBrowserTest {
 public:
  TvOSYouTubeSearchBrowserTest()
      : https_server_(net::EmbeddedTestServer::TYPE_HTTPS) {}

  void SetUpOnMainThread() override {
    ContentBrowserTest::SetUpOnMainThread();
    host_resolver()->AddRule("www.youtube.com", "127.0.0.1");

    net::EmbeddedTestServer::ServerCertificateConfig certificate;
    certificate.dns_names = {"www.youtube.com"};
    https_server_.SetSSLConfig(certificate);
    https_server_.RegisterRequestHandler(
        base::BindRepeating(&HandleYouTubeRequest));
    ASSERT_TRUE(https_server_.Start());

    GURL url = https_server_.GetURL("www.youtube.com", "/tv?launch=menu");
    GURL::Replacements replacements;
    replacements.SetRefStr("/search");
    ASSERT_TRUE(NavigateToURL(shell(), url.ReplaceComponents(replacements)));

    InjectAdapter();
    InjectAdapter();
  }

 protected:
  void InjectAdapter() {
    GeneratedResourceMap resources;
    CobaltTvOSJavaScript::GenerateMap(resources);
    const auto script = resources.find("tvos_youtube_search.js");
    ASSERT_NE(script, resources.end());
    ASSERT_TRUE(ExecJs(
        shell(), std::string(reinterpret_cast<const char*>(script->second.data),
                             script->second.size)));
  }

  net::EmbeddedTestServer https_server_;
};

IN_PROC_BROWSER_TEST_F(TvOSYouTubeSearchBrowserTest,
                       SearchRouteInputLifecycle) {
  EXPECT_EQ(kInputId,
            EvalJs(shell(), "document.activeElement.id").ExtractString());
  EXPECT_EQ("search:manual",
            EvalJs(shell(),
                   "document.activeElement.type + ':' + "
                   "document.activeElement.virtualKeyboardPolicy")
                .ExtractString());
  EXPECT_EQ(1, EvalJs(shell(), "document.querySelectorAll('#" +
                                   std::string(kInputId) + "').length")
                   .ExtractInt());

  EXPECT_TRUE(EvalJs(shell(), R"JS(
    (async () => {
      document.getElementById('previous').focus();
      await new Promise(resolve => setTimeout(resolve, 100));
      return document.activeElement.id ===
          'cobalt-tvos-youtube-search-input';
    })()
  )JS")
                  .ExtractBool());

  EXPECT_TRUE(EvalJs(shell(), R"JS(
    (async () => {
      location.hash = '/home';
      await new Promise(resolve => setTimeout(resolve, 0));
      return document.activeElement.id !==
          'cobalt-tvos-youtube-search-input';
    })()
  )JS")
                  .ExtractBool());

  EXPECT_TRUE(EvalJs(shell(), R"JS(
    (async () => {
      location.hash = '/search?q=existing';
      await new Promise(resolve => setTimeout(resolve, 0));
      return document.activeElement.id !==
          'cobalt-tvos-youtube-search-input';
    })()
  )JS")
                  .ExtractBool());

  EXPECT_TRUE(EvalJs(shell(), R"JS(
    (async () => {
      location.hash = '/search?vq=voice-result';
      await new Promise(resolve => setTimeout(resolve, 0));
      return document.activeElement.id !==
          'cobalt-tvos-youtube-search-input';
    })()
  )JS")
                  .ExtractBool());

  EXPECT_TRUE(EvalJs(shell(), R"JS(
    (async () => {
      document.getElementById('previous').focus();
      location.hash = '/search';
      await new Promise(resolve => setTimeout(resolve, 0));
      const input = document.getElementById(
          'cobalt-tvos-youtube-search-input');
      input.value = 'discard me';
      input.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'Escape', bubbles: true, cancelable: true
      }));
      return input.value === '' &&
          document.activeElement.id === 'previous' &&
          location.hash === '#/search';
    })()
  )JS")
                  .ExtractBool());

  EXPECT_TRUE(EvalJs(shell(), R"JS(
    (async () => {
      location.hash = '/home';
      await new Promise(resolve => setTimeout(resolve, 0));
      document.getElementById('previous').focus();
      location.hash = '/search';
      await new Promise(resolve => setTimeout(resolve, 0));
      const input = document.getElementById(
          'cobalt-tvos-youtube-search-input');
      input.value = '   ';
      input.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'Enter', bubbles: true, cancelable: true
      }));
      return location.hash === '#/search' &&
          document.activeElement.id === 'previous';
    })()
  )JS")
                  .ExtractBool());

  EXPECT_EQ("/tv?launch=menu#/search?inApp=true&q=caf%C3%A9+%26+music",
            EvalJs(shell(), R"JS(
    (async () => {
      location.hash = '/home';
      await new Promise(resolve => setTimeout(resolve, 0));
      location.hash = '/search';
      await new Promise(resolve => setTimeout(resolve, 0));
      const input = document.getElementById(
          'cobalt-tvos-youtube-search-input');
      input.value = '  café & music  ';
      input.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'Enter', bubbles: true, cancelable: true
      }));
      await new Promise(resolve => setTimeout(resolve, 0));
      return location.pathname + location.search + location.hash;
    })()
  )JS")
                .ExtractString());

  // Return to Search and verify a second submission reloads the completed
  // deep link instead of leaving YouTube's SPA search controller stale.
  ASSERT_TRUE(ExecJs(shell(), R"JS(
    (async () => {
      location.hash = '/home';
      await new Promise(resolve => setTimeout(resolve, 0));
      location.hash = '/search';
      await new Promise(resolve => setTimeout(resolve, 0));
    })()
  )JS"));
  TestNavigationObserver second_search_observer(shell()->web_contents(), 2);
  ASSERT_TRUE(ExecJs(shell(), R"JS(
    const input = document.getElementById(
        'cobalt-tvos-youtube-search-input');
    input.value = 'second query';
    input.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Enter', bubbles: true, cancelable: true
    }));
  )JS"));
  second_search_observer.Wait();
  EXPECT_EQ("/search?inApp=true&q=second+query",
            shell()->web_contents()->GetLastCommittedURL().ref());
}

}  // namespace
}  // namespace content
