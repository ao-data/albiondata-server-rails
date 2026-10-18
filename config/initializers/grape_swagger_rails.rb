GrapeSwaggerRails.options.url = '/api/v2/swagger_doc'
GrapeSwaggerRails.options.app_name = 'Albion Online Data Project API'

# app_url defaults to http://swagger.wordnik.com; point the UI at whichever host served the docs page,
# so west.<domain>/api-docs loads (and "Try it out" queries) west.<domain>/api/v2/swagger_doc.
GrapeSwaggerRails.options.before_action do |request|
  GrapeSwaggerRails.options.app_url = request.base_url
end
