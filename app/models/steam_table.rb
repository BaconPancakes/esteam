require 'csv'
require 'bsearch'

class SteamTable
  # define which thermodynamic property each column in the steam table represents
  PROPERTY= {temperature: 0, pressure: 1, v_f: 2, v_g: 3, u_f: 4, u_g: 5, h_f: 6, h_g: 7, s_f: 8, s_g: 9}

  # initialize steam table
  def initialize
    @table = CSV.read('app/models/water.csv', headers: true)
  end

# lookup method
  def lookup(rawparams)
    params = getparams(rawparams)

    # if the user has selected 'saturated'
    if rawparams[:saturated]
      return satlookup(params)

    else

    end
  end

  # private helper methods
  private

  # takes the raw parameters passed to the controller, extract the useful property data
  # not really necessary, but I don't like passing around random authenticity tokens.
  # returns a float hash of the useful properties. Leaves blanks if not present.
  def getparams(rawparams)

    temp = rawparams[:temperature]
    pres = rawparams[:pressure]
    quality = rawparams[:quality]
    v = rawparams[:specific_volume]
    u = rawparams[:specific_energy]
    h = rawparams[:specific_enthalpy]
    s = rawparams[:specific_entropy]

    return {temperature: temp, pressure: pres, quality: quality,
            specific_volume: v, specific_energy: u,
            specific_enthalpy: h, specific_entropy: s}

  end

  def satlookup(params)
    # if quality is given, check for pressure or temperature to lookup the rest.
    # return blank if nothing was done.
    if params[:quality].present?
      quality = params[:quality].to_f

      # if quality is not given, we need to solve for it
    else
      quality = solve_quality(params)
    end

    if quality.present?
      # If pressure is filled in
      if params[:pressure].present?
        pressure = params[:pressure].to_f
        return satlookup_from_pressure(pressure, quality)

        # else if temperature is filled in
      elsif params[:temperature].present?
        temperature = params[:temperature].to_f
        return satlookup_from_temperature(temperature, quality)
      end

    end
    return ''

  end

=begin
         # (?) If we have quality and two "specific" properties, we can calculate pressure or temperature.
      else
        pressure = pressure_from_quality(quality, specific_property1, specific_property2)
        return satlookup_from_pressure(pressure, quality)
      end
=end


  # given the quality and a specific_property, we can look up the pressure
  def pressure_from_quality(quality, specific_property1, specific_property2)
    # arbitrarily decide to calculate y_f (we can alternatively do y_g)
  end

  # attempts to solve for quality. If unable, returns blank
  def solve_quality(params)
    if params[:quality].present?
      raise 'quality is already given!'
    end

    # if temperature or pressure is given, then we only need a "specific" property
    if params[:temperature].present?
      temperature = params[:temperature].to_f

      # check each "specific property", return quality on first found
      [:specific_volume, :specific_energy, :specific_enthalpy, :specific_entropy].each do |property|
        if params[property].present?
          return quality_from_temp(temperature, property.to_s, params[property].to_f)
        end
      end

      # if temperature not present, check if pressure value is given
    elsif params[:pressure].present?
      pressure = params[:pressure].to_f

      # check each "specific property", return quality on first found
      [:specific_volume, :specific_energy, :specific_enthalpy, :specific_entropy].each do |property|
        if params[property].present?
          return quality_from_pressure(pressure, property.to_s, params[property].to_f)
        end
      end
    end
    return ''
  end

=begin
         # We should have two specific properties. Otherwise, quality calculation is not possible.
        count = 0
        [:specific_volume, :specific_energy, :specific_enthalpy, :specific_entropy].each do |property|
          count += 1 unless params[property].blank?
        end
        if count < 2
          return false
        end
=end


# for a saturated substance, given temperature and quality, look up pressure
# returns hash of all properties
  def satlookup_from_pressure(pressure, quality)
    index = search_column('pressure', pressure)
    temperature = interpolate(index, 'pressure', pressure, 'temperature')

    v_f = interpolate(index, 'pressure', pressure, 'v_f')
    v_g = interpolate(index, 'pressure', pressure, 'v_g')
    u_f = interpolate(index, 'pressure', pressure, 'u_f')
    u_g = interpolate(index, 'pressure', pressure, 'u_g')
    h_f = interpolate(index, 'pressure', pressure, 'h_f')
    h_g = interpolate(index, 'pressure', pressure, 'h_g')
    s_f = interpolate(index, 'pressure', pressure, 's_f')
    s_g = interpolate(index, 'pressure', pressure, 's_g')

    specific_volume = specifics_from_quality(quality, v_f, v_g)
    specific_energy = specifics_from_quality(quality, u_f, u_g)
    specific_enthalpy = specifics_from_quality(quality, h_f, h_g)
    specific_entropy = specifics_from_quality(quality, s_f, s_g)

    return {pressure: pressure, temperature: temperature, specific_volume: specific_volume,
            specific_energy: specific_energy, specific_enthalpy: specific_enthalpy,
            specific_entropy: specific_entropy, quality: quality}
  end

  # for a saturated substance, given pressure and quality, look up temperature
  # returns hash of all properties
  def satlookup_from_temperature(temperature, quality)
    index = search_column('temperature', temperature)
    pressure = interpolate(index, 'temperature', temperature, 'pressure')

    v_f = interpolate(index, 'temperature', temperature, 'v_f')
    v_g = interpolate(index, 'temperature', temperature, 'v_g')
    u_f = interpolate(index, 'temperature', temperature, 'u_f')
    u_g = interpolate(index, 'temperature', temperature, 'u_g')
    h_f = interpolate(index, 'pressure', temperature, 'h_f')
    h_g = interpolate(index, 'pressure', temperature, 'h_g')
    s_f = interpolate(index, 'pressure', temperature, 's_f')
    s_g = interpolate(index, 'pressure', temperature, 's_g')

    specific_volume = specifics_from_quality(quality, v_f, v_g)
    specific_energy = specifics_from_quality(quality, u_f, u_g)
    specific_enthalpy = specifics_from_quality(quality, h_f, h_g)
    specific_entropy = specifics_from_quality(quality, s_f, s_g)

    return {pressure: pressure, temperature: temperature, specific_volume: specific_volume,
            specific_energy: specific_energy, specific_enthalpy: specific_enthalpy,
            specific_entropy: specific_entropy, quality: quality}
  end


# given a string property name and its value, lookup and return the corresponding index of its column
  def search_column(property, value)
    # convert to symbol
    property = property.intern
    column = @table.map {|row| row[PROPERTY[property]].to_f}
    index = column.bsearch_lower_boundary{|x| x <=> value.to_f}
    return index
  end

# given a property, an index to its value, the closest value, and the desired property,
# interpolate to find the desired value
  def interpolate(index, property, value, desired_property)
    property = property.intern
    desired_property = desired_property.intern
    # TODO: Consider lower bound of index
    # if index == 0
    # return @table[index][PROPERTY[:pressure]].to_f
    #end

    a1 = @table[index-1][PROPERTY[desired_property]].to_f
    a2 = @table[index][PROPERTY[desired_property]].to_f
    b1 = @table[index-1][PROPERTY[property]].to_f
    b2 = @table[index][PROPERTY[property]].to_f
    result = a1 + (((value - b1)/(b2-b1)) * (a2-a1))
    return result.round(3)
  end

# given the quality, and the values of desired property
# as a saturated liquid or saturated gas, calculate the desired property
  def specifics_from_quality(quality, y_f, y_g)
    result = (quality/100) * (y_g-y_f) + y_f
    return result.round(3)
  end

# based on the input parameters, check if we can indeed solve for quality
  def solvable(params)
    # we need two independent properties
    count = 0

    # count each quantity
    params.each do |value|
      if value.present?
        count += 1
      end
    end

    # Assuming saturated, pressure and temperature are dependent. If both exist, we overcounted one
    if params[:quality].present?
      if params[:pressure].present? && params[:temperature].present?
        count -= 1;
      end
    end
    if count >= 2
      return true
    else return false
    end
  end

# given a temperature value, the string name of the "specific" property and its value, calculate quality
  def quality_from_temp(temperature_value, specific_property, value)
    index = search_column('temperature', temperature_value)
    # (messy) set up parameters for interpolation method
    case specific_property
      when 'specific_volume'
        y_f = 'v_f'
        y_g = 'v_g'
      when 'specific_energy'
        y_f = 'u_f'
        y_g = 'u_g'
      when 'specific_enthalpy'
        y_f = 'h_f'
        y_g = 'h_g'
      when 'specific_entropy'
        y_f = 's_f'
        y_g = 's_g'
      else raise 'Given property name not valid.'
    end

    y_f = interpolate(index, 'temperature', temperature_value, y_f)
    y_g = interpolate(index, 'temperature', temperature_value, y_g)

    quality = 100 * (value - y_f)/(y_g-y_f)
    if quality > 100
      quality = 100
    end
    return quality
  end

# given a pressure value, the string name of a "specific property" and its value, calculate quality
  def quality_from_pressure(pressure_value, specific_property, value)
    index = search_column('pressure', pressure_value)
    # (messy) set up parameters for interpolation method
    case specific_property
      when 'specific_volume'
        y_f = 'v_f'
        y_g = 'v_g'
      when 'specific_energy'
        y_f = 'u_f'
        y_g = 'u_g'
      when 'specific_enthalpy'
        y_f = 'h_f'
        y_g = 'h_g'
      when 'specific_entropy'
        y_f = 's_f'
        y_g = 's_g'
      else raise 'Given property name not valid.'
    end

    y_f = interpolate(index, 'pressure', pressure_value, y_f)
    y_g = interpolate(index, 'pressure', pressure_value, y_g)

    quality = 100 *(value - y_f)/(y_g-y_f)
    if quality > 100
      quality = 100
    end
    return quality
  end

end

