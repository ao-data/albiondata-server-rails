// Shadows grape-swagger-rails' own grape_swagger_rails/application.js (app asset paths win over the gem's), so the
// Swagger UI page can load curl_compressed below. The require list is copied from grape-swagger-rails 0.7.0; keep it
// in sync if that gem is upgraded.
//
//= require grape_swagger_rails/jquery-1.8.0.min
//= require grape_swagger_rails/jquery.slideto.min
//= require grape_swagger_rails/jquery.wiggle.min
//= require grape_swagger_rails/jquery.ba-bbq.min
//= require grape_swagger_rails/handlebars-2.0.0
//= require grape_swagger_rails/marked
//= require grape_swagger_rails/lodash.min
//= require grape_swagger_rails/backbone-min
//= require grape_swagger_rails/swagger-ui.min
//= require grape_swagger_rails/highlight.9.1.0.pack
//= require grape_swagger_rails/js-yaml.min
//= require grape_swagger_rails/jsoneditor.min
//= require grape_swagger_rails/object-assign-pollyfill
//= require grape_swagger_rails/swagger-oauth
//= require grape_swagger_rails/base64
//= require grape_swagger_rails/curl_compressed
