// Tweaks the request snippets Swagger UI shows after "Try it out":
//
// - curl gets --compressed. The API throttles clients that don't accept gzip/deflate/br/zstd to 6 requests a minute,
//   and --compressed (unlike a bare Accept-Encoding header) also makes curl decompress the body.
// - Python (requests), Node (fetch) and Ruby (HTTParty) snippets are added under the curl one, each sending
//   Accept-Encoding: gzip, deflate explicitly; all three still decompress those responses automatically.
//
// Swagger UI renders the curl block right after calling Operation#asCurl, so wrapping asCurl is the one hook for all of
// them. asCurl lives on swagger-js' Operation prototype, which is only reachable through an operation once the spec loads.
(function () {
  // Only gzip and deflate: requests decodes br/zstd only when the brotli/zstandard packages happen to be installed.
  var ACCEPT_ENCODING = 'gzip, deflate';

  function stringHeaders(request) {
    var headers = {};
    Object.keys(request.headers || {}).forEach(function (name) {
      if (typeof request.headers[name] === 'string') headers[name] = request.headers[name];
    });
    return headers;
  }

  function isXml(request) {
    return /([?&]format=xml\b|\.xml(\?|$))/.test(request.url);
  }

  function python(method, request) {
    var headers = stringHeaders(request);
    headers['Accept-Encoding'] = ACCEPT_ENCODING; // explicit, in case it's pasted into code with other session defaults
    var pairs = Object.keys(headers).map(function (name) {
      return JSON.stringify(name) + ': ' + JSON.stringify(headers[name]);
    });

    return [
      'import requests',
      '',
      'response = requests.' + method.toLowerCase() + '(',
      '    ' + JSON.stringify(request.url) + ',',
      '    headers={' + pairs.join(', ') + '},',
      ')',
      'response.raise_for_status()',
      isXml(request) ? 'print(response.text)' : 'print(response.json())'
    ].join('\n');
  }

  function node(method, request) {
    var headers = stringHeaders(request);
    headers['Accept-Encoding'] = ACCEPT_ENCODING; // fetch still decompresses from the response's Content-Encoding
    var pairs = Object.keys(headers).map(function (name) {
      return JSON.stringify(name) + ': ' + JSON.stringify(headers[name]);
    });
    var options = (method.toUpperCase() === 'GET' ? [] : ['  method: ' + JSON.stringify(method.toUpperCase()) + ','])
      .concat(['  headers: { ' + pairs.join(', ') + ' },']);

    return [
      '// Node 18+, as an ES module (e.g. a .mjs file) for top-level await',
      'const response = await fetch(' + JSON.stringify(request.url) + ', {'
    ].concat(options).concat([
      '});',
      'if (!response.ok) throw new Error(`HTTP ${response.status}`);',
      isXml(request) ? 'console.log(await response.text());' : 'console.log(await response.json());'
    ]).join('\n');
  }

  function ruby(method, request) {
    var rubyString = function (value) { return JSON.stringify(value).replace(/#/g, '\\#'); };
    var headers = stringHeaders(request);
    // Unlike plain Net::HTTP, HTTParty keeps gzip/deflate decompression on even when Accept-Encoding is set explicitly.
    headers['Accept-Encoding'] = ACCEPT_ENCODING;
    var pairs = Object.keys(headers).map(function (name) {
      return rubyString(name) + ' => ' + rubyString(headers[name]);
    });

    return [
      'require "httparty"',
      '',
      'response = HTTParty.' + method.toLowerCase() + '(',
      '  ' + rubyString(request.url) + ',',
      '  headers: { ' + pairs.join(', ') + ' },',
      ')',
      'raise "HTTP #{response.code}" unless response.success?',
      isXml(request) ? 'puts response.body' : 'pp response.parsed_response'
    ].join('\n');
  }

  var SNIPPETS = [
    { key: 'python', label: 'Python', build: python },
    { key: 'node', label: 'Node', build: node },
    { key: 'ruby', label: 'Ruby', build: ruby }
  ];

  // Swagger UI writes the curl block synchronously after asCurl returns, so by the next microtask it's in the DOM;
  // find it by its text and put the snippet blocks after it (or refresh the ones already there).
  function showSnippets(curl, snippets) {
    Promise.resolve().then(function () {
      document.querySelectorAll('div.block.curl:not(.snippet)').forEach(function (curlBlock) {
        if (curlBlock.textContent !== curl) return;

        var previous = curlBlock;
        snippets.forEach(function (snippet) {
          var block = curlBlock.parentNode.querySelector('div.block.snippet-' + snippet.key);
          if (!block) {
            var heading = document.createElement('h4');
            heading.className = 'curl snippet';
            heading.textContent = snippet.label;
            block = document.createElement('div');
            block.className = 'block curl snippet snippet-' + snippet.key;
            block.appendChild(document.createElement('pre'));
            previous.after(heading, block);
          }
          block.firstChild.textContent = snippet.code;
          previous = block;
        });
      });
    });
  }

  function patchAsCurl() {
    var api = window.swaggerUi && window.swaggerUi.api;
    var operation = api && api.apisArray && api.apisArray[0] && api.apisArray[0].operationsArray[0];
    if (!operation) return false;

    var proto = Object.getPrototypeOf(operation);
    if (!proto.asCurl.patched) {
      var asCurl = proto.asCurl;
      proto.asCurl = function (args, opts) {
        var curl = asCurl.apply(this, arguments).replace(/^curl /, 'curl --compressed ');

        // Build the same mock request asCurl does internally, for the other snippets.
        var mockOpts = { mock: true };
        for (var key in opts) mockOpts[key] = opts[key];
        var request = this.execute(args, mockOpts);
        if (this.clientAuthorizations) this.clientAuthorizations.apply(request, this.operation.security);

        var method = this.method;
        showSnippets(curl, SNIPPETS.map(function (snippet) {
          return { key: snippet.key, label: snippet.label, code: snippet.build(method, request) };
        }));

        return curl;
      };
      proto.asCurl.patched = true;
    }
    return true;
  }

  var timer = setInterval(function () {
    if (patchAsCurl()) clearInterval(timer);
  }, 100);
})();
