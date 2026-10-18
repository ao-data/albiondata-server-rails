// Tweaks the request snippets Swagger UI shows after "Try it out":
//
// - curl gets --compressed. The API throttles clients that don't accept gzip/deflate/br/zstd to 6 requests a minute,
//   and --compressed (unlike a bare Accept-Encoding header) also makes curl decompress the body.
// - A Python (requests) snippet is added under the curl one, sending Accept-Encoding: gzip, deflate for the same
//   throttle; requests decompresses those responses automatically.
//
// Swagger UI renders the curl block right after calling Operation#asCurl, so wrapping asCurl is the one hook for both.
// asCurl lives on swagger-js' Operation prototype, which is only reachable through an operation once the spec loads.
(function () {
  function pythonSnippet(method, request) {
    var headerValues = {};
    Object.keys(request.headers || {}).forEach(function (name) {
      if (typeof request.headers[name] === 'string') headerValues[name] = request.headers[name];
    });
    // Explicit so the snippet stays compressed even if pasted into code with other session defaults. Only gzip and
    // deflate: requests decodes br/zstd only when the brotli/zstandard packages happen to be installed.
    headerValues['Accept-Encoding'] = 'gzip, deflate';
    var headers = Object.keys(headerValues).map(function (name) {
      return JSON.stringify(name) + ': ' + JSON.stringify(headerValues[name]);
    });
    var xml = /([?&]format=xml\b|\.xml(\?|$))/.test(request.url);

    return [
      'import requests',
      '',
      'response = requests.' + method.toLowerCase() + '(',
      '    ' + JSON.stringify(request.url) + ','
    ].concat(headers.length ? ['    headers={' + headers.join(', ') + '},'] : []).concat([
      ')',
      'response.raise_for_status()',
      xml ? 'print(response.text)' : 'print(response.json())'
    ]).join('\n');
  }

  // Swagger UI writes the curl block synchronously after asCurl returns, so by the next microtask it's in the DOM;
  // find it by its text and put the Python block after it (or refresh the one already there).
  function showPython(curl, python) {
    Promise.resolve().then(function () {
      document.querySelectorAll('div.block.curl:not(.python)').forEach(function (curlBlock) {
        if (curlBlock.textContent !== curl) return;

        var pythonBlock = curlBlock.nextElementSibling && curlBlock.nextElementSibling.nextElementSibling;
        if (!pythonBlock || !pythonBlock.classList.contains('python')) {
          var heading = document.createElement('h4');
          heading.className = 'curl python';
          heading.textContent = 'Python';
          pythonBlock = document.createElement('div');
          pythonBlock.className = 'block curl python';
          pythonBlock.appendChild(document.createElement('pre'));
          curlBlock.after(heading, pythonBlock);
        }
        pythonBlock.firstChild.textContent = python;
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

        // Build the same mock request asCurl does internally, for the Python snippet.
        var mockOpts = { mock: true };
        for (var key in opts) mockOpts[key] = opts[key];
        var request = this.execute(args, mockOpts);
        if (this.clientAuthorizations) this.clientAuthorizations.apply(request, this.operation.security);
        showPython(curl, pythonSnippet(this.method, request));

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
