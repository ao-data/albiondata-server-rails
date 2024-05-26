module Quality

  DEFAULT_QUALITIES = [1,2,3,4,5]

  def get_qualities(params)
    qualities = params[:qualities]

    # qualities = nil if params[:query_string].include?('qualities[]')
    qualities = qualities.map(&:to_i) if qualities.is_a?(Array) && qualities[0].is_a?(String)

    qualities = DEFAULT_QUALITIES if qualities.nil? || qualities == 0 || qualities == '0'
    qualities = qualities.split(',').map(&:to_i) if qualities.is_a?(String)

    qualities
  end

end
