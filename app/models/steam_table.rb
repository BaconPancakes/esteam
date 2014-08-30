require 'csv'
require 'bsearch'
class SteamTable
  attr_reader :values
  # define which thermodynamic property each column in the steam table represents
  PROPERTY= {:temperature => 0, :pressure => 1, :v_f => 2, :v_g => 3, :u_f => 4, :u_g => 5}

  # initialize steam table
  def initialize
    @table = CSV.read('app/models/water part1.csv')
  end

# lookup method
  def lookup(params)
    if params[:saturated]
      return satlookup(params)
    end
  end

  # private helper methods
  private

  def satlookup(params)
    # if quality is given, check for pressure or temperature to lookup the rest.
    if params[:quality] != ''
      quality = params[:quality].to_f

      # If pressure is filled in
      if params[:pressure] != ''
        pressure = params[:pressure].to_f
        return satlookup_from_pressure(pressure, quality)
      end
      # else if temperature is filled in
      if params[:temperature] != ''
        temperature = params[:temperature].to_f
        return satlookup_from_temperature(temperature,quality)
      end
      # if we don't have quality, then we need to solve for it
      # check if there's enough information to solve it
     isQualitySolvable(params)
    else
      if params[:specific_volume] != ''

      end
    end
  end


  # for a saturated substance, given temperature and quality, look up pressure
  # returns hash of all other properties
  def satlookup_from_pressure(pressure, quality)
    index = search_column('pressure', pressure)
    temperature = interpolate(index, 'pressure', pressure, 'temperature')
    v_f = interpolate(index, 'pressure', pressure, 'v_f')
    v_g = interpolate(index, 'pressure', pressure, 'v_g')
    u_f = interpolate(index, 'pressure', pressure, 'u_f')
    u_g = interpolate(index, 'pressure', pressure, 'u_g')
    specific_volume = calculate_from_quality(quality, v_f, v_g)
    specific_energy = calculate_from_quality(quality, u_f, u_g)
    return {pressure: pressure, temperature: temperature, specific_volume: specific_volume,
            specific_energy: specific_energy}
    end

    def satlookup_from_temperature(temperature, quality)
      index = search_column('temperature', temperature)
      pressure = interpolate(index, 'temperature', temperature, 'pressure')
      v_f = interpolate(index, 'temperature', temperature, 'v_f')
      v_g = interpolate(index, 'temperature', temperature, 'v_g')
      u_f = interpolate(index, 'temperature', temperature, 'u_f')
      u_g = interpolate(index, 'temperature', temperature, 'u_g')
      specific_volume = calculate_from_quality(quality, v_f, v_g)
      specific_energy = calculate_from_quality(quality, u_f, u_g)
      return {pressure: pressure, temperature: temperature, specific_volume: specific_volume,
              specific_energy: specific_energy}
    end


    # given a property and its value, lookup and return the corresponding index of its column
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
    # as a saturated liquid or saturated gas, calculate the desired
    # property (specific volume, energy for now)

    def calculate_from_quality(quality, y_f, y_g)
      result = (quality/100) * (y_g-y_f) + y_f
      return result.round(3)
    end

  # based on the input paramaters, check if we can indeed solve for quality
  def isQualitySolvable(params)
    # we need two independent properties
    count = 0
    # Assuming saturated, pressure and temperature are dependent. Count either or both as one.
    if params[pressure] = ''
  end


  end

  end
