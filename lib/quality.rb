module Quality

  def get_qualities(params)
    qualities = params[:qualities]

    # qualities = nil if params[:query_string].include?('qualities[]')
    qualities = qualities.map(&:to_i) if qualities.is_a?(Array) && qualities[0].is_a?(String)

    qualities = [1] if qualities.nil?
    qualities = [1,2,3,4,5] if qualities == 0 || qualities == '0'
    qualities = qualities.split(',').map(&:to_i) if qualities.is_a?(String)

    qualities
  end

end
