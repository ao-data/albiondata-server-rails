require 'abuseipdb'
require 'redis'

class Ipdb
  API_RATE_LIMIT_REMAINING_KEY = 'apidb-rate-limit-remaining'
  # Sorted set of bad IPs, scored by the unix time they were flagged. A sorted set rather than a plain set
  # so entries can expire individually; this is a new key because the old 'bad_ips' key is a plain set.
  BAD_IPS_KEY = 'bad_ips_by_time'
  BAD_IP_TTL = 86400 * 3
  CHECKED_IPS_KEY_PREFIX = 'checked_ip_'

  def api_key
    ENV['ABUSEIPDB_API_KEY']
  end

  def check_ip(ip)
    # Always assume IP is okay if we have no API key defined
    return true if api_key.blank?

    # return false if the ip was added to the bad list within BAD_IP_TTL; once older than that, it gets rechecked
    flagged_at = ABUSEIPDB_REDIS.zscore(BAD_IPS_KEY, ip)
    return false if flagged_at && flagged_at > Time.now.to_i - BAD_IP_TTL

    # return true if the ip was checked and came back clean
    recently_checked = ABUSEIPDB_REDIS.get("#{CHECKED_IPS_KEY_PREFIX}#{ip}")
    return true if recently_checked

    # if we dont have an api key, just return true
    return true if api_key.nil?

    # check if we are close to rate limit
    rate_limit_remaining = ABUSEIPDB_REDIS.get(API_RATE_LIMIT_REMAINING_KEY)

    # if we are close to rate limit, just return true, we'll check it later
    return true if !rate_limit_remaining.nil? && rate_limit_remaining.to_i <= 100
    rate_limit_remaining = rate_limit_remaining.to_i

    c = nil
    r = nil
    score = 0
    begin
      # check ip with abuseipdb
      c = Abuseipdb.client
      r = c.check.call(ipAddress: ip)
      score = r.body['data']['abuseConfidenceScore']
    rescue StandardError => e
      pp e
      # there was an error, assume the ip is ok for now, abuseipdb will be back soon
      return true
    end

    # store api rate limit remaining
    rate_limit_remaining = r.raw_response.env.response_headers['x-ratelimit-remaining'].to_i
    ABUSEIPDB_REDIS.set(API_RATE_LIMIT_REMAINING_KEY, rate_limit_remaining, ex: 1800)

    if score > ENV['ABUSEIPDB_SCORE_THRESHOLD'].to_i
      # add ip to bad list (re-adding an expired ip refreshes its timestamp), and drop entries older than the TTL
      now = Time.now.to_i
      ABUSEIPDB_REDIS.zadd(BAD_IPS_KEY, now, ip)
      ABUSEIPDB_REDIS.zremrangebyscore(BAD_IPS_KEY, '-inf', now - BAD_IP_TTL)

      return false
    else
      # cache passed check for 7 days
      ABUSEIPDB_REDIS.set("#{CHECKED_IPS_KEY_PREFIX}#{ip}", 1, ex: 86400 * 7)

      return true
    end
  end
end

