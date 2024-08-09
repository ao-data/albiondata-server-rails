class IdentifierService
  def self.add_identifier_event(opts, event, expiration = 600)

    # Ensure opts is a hash
    opts = opts.is_a?(Hash) ? opts : JSON.parse(opts) rescue {}

    identifier = opts["identifier"] || opts[:identifier]

    if identifier.nil?
      return
    end

    key = "IDENTIFIER:#{identifier}"

    event_object = {
      timestamp: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S'),
      event: event
    }

    event_json = event_object.to_json

    # Append the event description to the list associated with the identifier
    REDIS['identifier'].rpush(key, event_json)

    # Set an expiration time for the key
    REDIS['identifier'].expire(key, expiration)
  end
end
