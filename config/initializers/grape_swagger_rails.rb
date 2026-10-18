GrapeSwaggerRails.options.url = '/api/v2/swagger_doc'
GrapeSwaggerRails.options.app_name = 'Albion Online Data Project API'

# app_url defaults to http://swagger.wordnik.com. Leave it blank so the UI requests the relative url above, which the
# browser resolves against whichever host served the page (west.<domain>/api-docs -> west.<domain>/api/v2/swagger_doc).
# Don't set it per-request from request.base_url: options are global, so a spoofed Host header would stick for others.
GrapeSwaggerRails.options.app_url = ''
