class SteamTableController < ApplicationController
  def lookup

    # else
    table = SteamTable.new
    @results = table.lookup(params)
    render 'pages/home'
  end
end