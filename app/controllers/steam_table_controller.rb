class SteamTableController < ApplicationController
  def lookup
    # redirect_to root_path if params.blank?
    table = SteamTable.new
    @results = table.lookup(params)
    unless @results[:status] == 'success'
      flash[:info] = 'Something went wrong. (Are you sure about that saturation region?)'
      redirect_to root_path
      #@params = params
    else
      render 'pages/home'
    end
  end
end