require 'csv'
require 'bsearch'

class SteamTable

  # define which thermodynamic property each column in the steam table represents
  SAT_PROPERTY= {temperature: 0, pressure: 1, v_f: 2, v_g: 3, u_f: 4, u_g: 5, h_f: 6, h_g: 7, s_f: 8, s_g: 9}
  PROPERTY = {temperature: 0, pressure: 1, v: 2, u: 3, h: 4, s: 5, state: 6 }

  # array of all properties, for easy iteration
  ALL_PROPERTIES = [:temperature, :pressure, :specific_volume, :specific_energy, :specific_enthalpy, :specific_entropy]

  # initialize steam table
  def initialize
    @sat_table = CSV.read('app/models/water_sat.csv', headers: true)
    @table = CSV.read('app/models/water.csv', headers: true)
  end

# lookup method
  def lookup(rawparams)
    params = getparams(rawparams)
    return unless solvable(params)

    # if the user has selected 'saturated', run satlookup
    if rawparams[:saturated]
      return satlookup(params)

      # else we have the regular procedure
    else

      # select two parameters from params
      property1 = ''
      property2 = ''
      value1 = ''
      value2 = ''

      # ends up selecting the first and last parameters
      ALL_PROPERTIES.each do |property|
        unless property1.present?
          if params[property].present?
            property1 = property
            value1 = params[property]
          end
        end

        if property1.present?
          if params[property].present?
            property2 = property
            value2 = params[property]
          end
        end
      end

      # take the two parameters and look in the table for a match for either
      index = nil
      sort_by(property1.to_s,property2.to_s)
      range1 = @table.bsearch_range{|row| row[PROPERTY[property1]].to_f <=> value1.to_f}
      # if an actual match, search the next column.
      range1.each do |i|
        if @table[i][PROPERTY[property1]].to_f == value1.to_f
          index = @table.bsearch_lower_boundary (range1) {|row| row[PROPERTY[property2]].to_f <=> value2.to_f}
        end
      end
      #interpolate for the column without a match
      result = interpolate_all(index.to_i, property2.to_s, property1.to_s, value2,  value1)

      unless index.present?
        sort_by(property2, property1)
        range2 = @table.bsearch_range{|row| row[PROPERTY[property2]].to_f <=> value2.to_f}
        range2.each do |i|
          if @table[i][PROPERTY[property2]].to_f == value2.to_f
            index = @table.bsearch_lower_boundary (range2) {|row| row[PROPERTY[property1]].to_f <=> value1.to_f}
          end
        end
        # interpolate for the column without a match
        result = interpolate_all(index.to_i, property1.to_s, property2.to_s, value1, value2)
      end
      unless index.present?
        # if neither matches, we must do double interpolation
        # requires finding two indices corresponding to the four table rows necessary for double interpolation
        # we search for a bracket of values for property1, and within that, a bracket of values for property2
        sort_by(property1, property2)
        # find the boundary value for property1
        i = @table.bsearch_lower_boundary {|row| row[PROPERTY[property1]].to_f <=> value1.to_f}
        # find the range of values corresponding to the lower bracket i-1 and the upper bracket i
        range1 = @table.bsearch_range {|row| row[PROPERTY[property1]].to_f <=> @table[i-1][PROPERTY[property1]].to_f}
        range2 = @table.bsearch_range {|row| row[PROPERTY[property1]].to_f <=> @table[i][PROPERTY[property1]].to_f}

        # within these range, find the indices for the brackets of property2
        index1 = @table.bsearch_lower_boundary (range1) {|row| row[PROPERTY[property2]].to_f <=> value2.to_f}
        index2 = @table.bsearch_lower_boundary (range2) {|row| row[PROPERTY[property2]].to_f <=> value2.to_f}

        result = double_interpolate_all(index1, index2, property1.to_s, property2.to_s, value1, value2)
      end

      return result
    end
  end

# private helper methods
  private


# takes the raw parameters passed to the controller, extract the useful property data
# not really necessary, but I don't like passing around random authenticity tokens.
# returns a float hash of the useful properties. Leaves blanks if not present.
  def getparams(rawparams)

    temp = rawparams[:temperature].to_f if rawparams[:temperature].present?
    pres = rawparams[:pressure].to_f if rawparams[:pressure].present?
    quality = rawparams[:quality].to_f if rawparams[:quality].present?
    v = rawparams[:specific_volume].to_f if rawparams[:specific_volume].present?
    u = rawparams[:specific_energy].to_f if rawparams[:specific_energy].present?
    h = rawparams[:specific_enthalpy].to_f if rawparams[:specific_enthalpy].present?
    s = rawparams[:specific_entropy].to_f if rawparams[:specific_entropy].present?

    return {temperature: temp, pressure: pres, quality: quality,
            specific_volume: v, specific_energy: u,
            specific_enthalpy: h, specific_entropy: s}

  end

  # double interpolates all other values for given property names and values
  def double_interpolate_all(index1, index2, property1, property2, value1, value2)

    unless property1 == 'specific_volume' || property2 == 'specific_volume'
      v = double_interpolate(index1, index2, property1, property2, value1, value2, 'v')
    end
    unless property1 == 'specific_energy' || property2 == 'specific_energy'
      u = double_interpolate(index1, index2, property1, property2, value1, value2, 'u')
    end
    unless property1 == 'specific_enthalpy' || property2 == 'specific_enthalpy'
      h = double_interpolate(index1, index2, property1, property2, value1, value2, 'h')
    end
    unless property1 == 'specific_entropy' || property2 == 'specific_entropy'
      s = double_interpolate(index1, index2, property1, property2, value1, value2, 's')
    end
    unless property1 == 'pressure' || property2 == 'pressure'
      pres = double_interpolate(index1, index2, property1, property2, value1, value2, 'pressure')
    end
    unless property1 == 'temperature' || property2 == 'temperature'
      temp = double_interpolate(index1, index2, property1, property2, value1, value2, 'temperature')
    end

    # assign the remaining property1, property2 (messy)

    case property1
      when 'pressure'
        pres = value1
      when 'temperature'
        temp = value1
      when 'specific_volume'
        v = value1
      when 'specific_entropy'
        s = value1
      when 'specific_energy'
        u = value1
      when 'specific_enthalpy'
        h = value1
      else
        raise 'property1 not valid'
    end

    case property2
      when 'pressure'
        pres = value2
      when 'temperature'
        temp = value2
      when 'specific_volume'
        v = value2
      when 'specific_entropy'
        s = value2
      when 'specific_energy'
        u = value2
      when 'specific_enthalpy'
        h = value2
      else
        raise 'property2 not valid'
    end

    return {temperature: temp, pressure: pres,
            specific_volume: v, specific_energy: u,
            specific_enthalpy: h, specific_entropy: s}
  end


  #takes two string property names and corresponding values. Looks up all values.
  def interpolate_all(index, property1, property2, value1, value2)

    # interpolate for the rest of the values
    unless property1 == 'specific_volume' || property2 == 'specific_volume'
      v = interpolate(index, property1, value1, 'v')
    end
    unless property1 == 'specific_energy' || property2 == 'specific_energy'
      u = interpolate(index, property1, value1, 'u')
    end
    unless property1 == 'specific_enthalpy' || property2 == 'specific_enthalpy'
      h = interpolate(index, property1, value1, 'h')
    end
    unless property1 == 'specific_entropy' || property2 == 'specific_entropy'
      s = interpolate(index, property1, value1, 's')
    end
    unless property1 == 'pressure' || property2 == 'pressure'
      pres = interpolate(index, property1, value1, 'pressure')
    end
    unless property1 == 'temperature' || property2 == 'temperature'
      temp = interpolate(index, property1, value1, 'temperature')
    end

    # assign the remaining property1, property2 (messy)

    case property1
      when 'pressure'
        pres = value1
      when 'temperature'
        temp = value1
      when 'specific_volume'
        v = value1
      when 'specific_entropy'
        s = value1
      when 'specific_energy'
        u = value1
      when 'specific_enthalpy'
        h = value1
      else
        raise 'property1 not valid'
    end

    case property2
      when 'pressure'
        pres = value2
      when 'temperature'
        temp = value2
      when 'specific_volume'
        v = value2
      when 'specific_entropy'
        s = value2
      when 'specific_energy'
        u = value2
      when 'specific_enthalpy'
        h = value2
      else
        raise 'property2 not valid'
    end

    return {temperature: temp, pressure: pres,
            specific_volume: v, specific_energy: u,
            specific_enthalpy: h, specific_entropy: s}
  end

  def satlookup(params)
    # if quality is given, check for pressure or temperature to lookup the rest.
    # return blank if nothing was done.
    if params[:quality].present?
      quality = params[:quality]

      # if quality is not given, we need to solve for it
    else
      quality = solve_quality(params)
    end

    if quality.present?
      # If pressure is filled in
      if params[:pressure].present?
        pressure = params[:pressure]
        return satlookup_from_pressure(pressure, quality)

        # else if temperature is filled in
      elsif params[:temperature].present?
        temperature = params[:temperature]
        return satlookup_from_temperature(temperature, quality)
      end

      # at the very least, if we have temperature we can solve for pressure and vice versa
    else
      if params[:pressure].present?
        pressure = params[:pressure]
        index = sat_search_column('pressure', pressure)
        temperature = sat_interpolate(index, 'pressure', pressure, 'temperature')
        return {pressure: pressure, temperature: temperature}
      end

      if params[:temperature].present?
        temperature = params[:temperature]
        index = sat_search_column('temperature', temperature)
        pressure = sat_interpolate(index, 'temperature', temperature, 'pressure')
        return {pressure: pressure, temperature: temperature}
      end
    end
    return ''
  end


# attempts to solve for quality. If unable, returns blank
  def solve_quality(params)
    if params[:quality].present?
      raise 'quality is already given!'
    end

    # if temperature or pressure is given, then we only need a "specific" property
    if params[:temperature].present?
      temperature = params[:temperature]

      # check each "specific property", return quality on first found
      [:specific_volume, :specific_energy, :specific_enthalpy, :specific_entropy].each do |property|
        if params[property].present?
          return quality_from_temp(temperature, property.to_s, params[property]).round(3)
        end
      end

      # if temperature not present, check if pressure value is given
    elsif params[:pressure].present?
      pressure = params[:pressure]

      # check each "specific property", return quality on first found
      [:specific_volume, :specific_energy, :specific_enthalpy, :specific_entropy].each do |property|
        if params[property].present?
          return quality_from_pressure(pressure, property.to_s, params[property]).round(3)
        end
      end
    end
    return ''
  end

# for a saturated substance, given temperature and quality, look up pressure
# returns hash of all properties
  def satlookup_from_pressure(pressure, quality)
    index = sat_search_column('pressure', pressure)
    temperature = sat_interpolate(index, 'pressure', pressure, 'temperature')

    v_f = sat_interpolate(index, 'pressure', pressure, 'v_f')
    v_g = sat_interpolate(index, 'pressure', pressure, 'v_g')
    u_f = sat_interpolate(index, 'pressure', pressure, 'u_f')
    u_g = sat_interpolate(index, 'pressure', pressure, 'u_g')
    h_f = sat_interpolate(index, 'pressure', pressure, 'h_f')
    h_g = sat_interpolate(index, 'pressure', pressure, 'h_g')
    s_f = sat_interpolate(index, 'pressure', pressure, 's_f')
    s_g = sat_interpolate(index, 'pressure', pressure, 's_g')

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
    index = sat_search_column('temperature', temperature)
    pressure = sat_interpolate(index, 'temperature', temperature, 'pressure')

    v_f = sat_interpolate(index, 'temperature', temperature, 'v_f')
    v_g = sat_interpolate(index, 'temperature', temperature, 'v_g')
    u_f = sat_interpolate(index, 'temperature', temperature, 'u_f')
    u_g = sat_interpolate(index, 'temperature', temperature, 'u_g')
    h_f = sat_interpolate(index, 'pressure', temperature, 'h_f')
    h_g = sat_interpolate(index, 'pressure', temperature, 'h_g')
    s_f = sat_interpolate(index, 'pressure', temperature, 's_f')
    s_g = sat_interpolate(index, 'pressure', temperature, 's_g')

    specific_volume = specifics_from_quality(quality, v_f, v_g)
    specific_energy = specifics_from_quality(quality, u_f, u_g)
    specific_enthalpy = specifics_from_quality(quality, h_f, h_g)
    specific_entropy = specifics_from_quality(quality, s_f, s_g)

    return {pressure: pressure, temperature: temperature, specific_volume: specific_volume,
            specific_energy: specific_energy, specific_enthalpy: specific_enthalpy,
            specific_entropy: specific_entropy, quality: quality}
  end


# sorts by property1, then property2 (ascending)
# returns the sorted table instance
  def sort_by(property1, property2)
    property1 = property1.intern
    property2 = property2.intern
    @table = @table.sort do  |row, nextrow|
      comp = row[PROPERTY[property1]].to_f <=> nextrow[PROPERTY[property1]].to_f
      comp.zero? ? (row[PROPERTY[property2]].to_f <=> nextrow[PROPERTY[property2]].to_f) : comp
    end

  end


# given a string property name and its value, lookup and return the corresponding index of its column
# searches for the lower_boundary, if not the match
# works for sorted temperature/pressure lookups (saturated table)
  def sat_search_column(property, value)
    # convert to symbol
    property = property.intern
    column = @sat_table.map {|row| row[SAT_PROPERTY[property]].to_f}
    index = column.bsearch_lower_boundary{|x| x <=> value.to_f}
    return index
  end

# for saturated substances, given a property, an index to its value, the closest value, and the desired property,
# interpolate to find the desired value
  def sat_interpolate(index, property, value, desired_property)
    property = property.intern
    desired_property = desired_property.intern
    # TODO: Consider lower bound of index
    # if index == 0
    # return @sat_table[index][SAT_PROPERTY[:pressure]].to_f
    #end

    a1 = @sat_table[index][SAT_PROPERTY[desired_property]].to_f
    a2 = @sat_table[index-1][SAT_PROPERTY[desired_property]].to_f
    b1 = @sat_table[index][SAT_PROPERTY[property]].to_f
    b2 = @sat_table[index-1][SAT_PROPERTY[property]].to_f
    result = a1 + ((((value - b1))/(b2-b1)) * (a2-a1))
    return result.round(3)
  end

# given the quality, and the values of desired property
# as a saturated liquid or saturated gas, calculate the desired property
  def specifics_from_quality(quality, y_f, y_g)
    result = (quality/100) * (y_g-y_f) + y_f
    return result.round(3)
  end

  # for unsaturated substances in the case where neither of the properties are in the table, use double interpolation
  # requires two indexes that correspond to the two pairs of adjacent entries needed for double interpolation
  def double_interpolate(index1, index2, property1, property2, value1, value2, desired_property)
    property1 = property1.intern
    property2 = property2.intern
    desired_property = desired_property.intern

    # fill in the gap for property1
    a1 = @table[index1-1][PROPERTY[desired_property]].to_f
    a2 = @table[index1][PROPERTY[desired_property]].to_f
    b1 = @table[index1-1][PROPERTY[property2]].to_f
    b2 = @table[index1][PROPERTY[property2]].to_f
    y1 = a1 + ((((value2 - b1))/(b2-b1)) * (a2-a1))

    # gap for property2
    a1 = @table[index2-1][PROPERTY[desired_property]].to_f
    a2 = @table[index2][PROPERTY[desired_property]].to_f
    b1 = @table[index2-1][PROPERTY[property2]].to_f
    b2 = @table[index2][PROPERTY[property2]].to_f
    y2 = a1 + ((((value2 - b1))/(b2-b1)) * (a2-a1))

    # now interpolate using found values
    b1 = @table[index1][PROPERTY[property1]].to_f
    b2 = @table[index2][PROPERTY[property1]].to_f
    result = y1 + ((((value1 - b1))/(b2-b1)) * (y2-y1))

    return result.round(3)

  end

  # for unsaturated substances, given a property, an index to its value, the closest value, and the desired property,
  # interpolate to find the desired value
  def interpolate(index, property, value, desired_property)
    property = property.intern
    desired_property = desired_property.intern
    # TODO: Consider lower bound of index
    # if index == 0
    # return @sat_table[index][SAT_PROPERTY[:pressure]].to_f
    #end

    a1 = @table[index][PROPERTY[desired_property]].to_f
    a2 = @table[index-1][PROPERTY[desired_property]].to_f
    b1 = @table[index][PROPERTY[property]].to_f
    b2 = @table[index-1][PROPERTY[property]].to_f
    result = a1 + ((((value - b1))/(b2-b1)) * (a2-a1))
    return result.round(3)
  end


# based on the input parameters, check if we can indeed solve for this
  def solvable(params)
    # we need two independent properties
    count = 0

    # count each quantity
    params.each do |key, value|
      count += 1 if value.present?
    end

    # Assuming saturated, pressure and temperature are dependent. If both exist, we overcounted one
    if params[:saturated].present?
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
    index = sat_search_column('temperature', temperature_value)
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

    y_f = sat_interpolate(index, 'temperature', temperature_value, y_f)
    y_g = sat_interpolate(index, 'temperature', temperature_value, y_g)

    quality = 100 * (value - y_f)/(y_g-y_f)
    if quality > 100
      quality = 100
    end
    return quality
  end

# given a pressure value, the string name of a "specific property" and its value, calculate quality
# @return [float]
  def quality_from_pressure(pressure_value, specific_property, value)
    index = sat_search_column('pressure', pressure_value)
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

    y_f = sat_interpolate(index, 'pressure', pressure_value, y_f)
    y_g = sat_interpolate(index, 'pressure', pressure_value, y_g)

    # convert to % units
    quality = 100 *(value - y_f)/(y_g-y_f)
    if quality > 100
      quality = 100
    end
    return quality
  end

end

