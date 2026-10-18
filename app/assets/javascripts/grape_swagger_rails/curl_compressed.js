// Make Swagger UI's generated curl commands request a compressed response. The API throttles clients that don't
// accept gzip/deflate/br/zstd to 6 requests a minute, and --compressed (unlike a bare Accept-Encoding header) also
// makes curl decompress the body instead of printing raw gzip.
//
// asCurl lives on swagger-js' Operation prototype, which is only reachable through an operation once the spec loads.
(function () {
  function patchAsCurl() {
    var api = window.swaggerUi && window.swaggerUi.api;
    var operation = api && api.apisArray && api.apisArray[0] && api.apisArray[0].operationsArray[0];
    if (!operation) return false;

    var proto = Object.getPrototypeOf(operation);
    if (!proto.asCurl.compressed) {
      var asCurl = proto.asCurl;
      proto.asCurl = function () {
        return asCurl.apply(this, arguments).replace(/^curl /, 'curl --compressed ');
      };
      proto.asCurl.compressed = true;
    }
    return true;
  }

  var timer = setInterval(function () {
    if (patchAsCurl()) clearInterval(timer);
  }, 100);
})();
