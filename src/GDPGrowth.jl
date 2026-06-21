module GDPGrowth

using CSV, Chain, DataFrames, Downloads, GLM, Plots, StatsBase
export get_gdp_per_capita_dataframe, growth_rate, generate_growth_dataframe, plot_growth_rates, regression

const COUNTRIES = [
  "AUS", "ALB", "ABW", #write all countries you want to include in the analysis in here
]

function get_gdp_per_capita_dataframe()
  url = "https://ourworldindata.org/grapher/gdp-per-capita-penn-world-table.csv?v=1&csvType=full&useColumnShortNames=true"
  return CSV.read(Downloads.download(url), DataFrame)
end

to_long_form(df) = unstack(df[:, Not(:entity)], :code, :rgdpo_pc)
select_year_period(df, period_start, period_end) = df[period_start.≤df.year.≤period_end, :]
select_countries(df, countries) = filter(:code => x -> x ∈ countries, df)

function growth_rate(df, start_year, end_year, country)
  start_value = first(df[df.year.==start_year, country])
  end_value = first(df[df.year.==end_year, country])
  return (log(end_value) - log(start_value)) / (end_year - start_year)
end

function countries_with_data(df, year1, year2)
  codes = unique(df.code)

  return filter(
    code -> begin
      years = df[df.code.==code, :year]
      year1 in years && year2 in years
    end, codes
  )
end

function generate_growth_dataframe(gdp_per_df, start_year, end_year; included_countries=nothing)

  countries = if isnothing(included_countries)
    countries_with_data(gdp_per_df, start_year, end_year)
  else
    intersect(countries_with_data(gdp_per_df, start_year, end_year), included_countries)
  end

  gdp_per_c_pivot = to_long_form(gdp_per_df)

  return DataFrame(
    countries=countries,
    gdp_growth=[growth_rate(gdp_per_c_pivot, start_year, end_year, c) for c in countries],
    gdp=[first(gdp_per_c_pivot[gdp_per_c_pivot.year.==start_year, c]) for c in countries],
    log_gdp=[log(first(gdp_per_c_pivot[gdp_per_c_pivot.year.==start_year, c])) for c in countries]
  )
end

function plot_growth_rates(growth_rate_df)
  return scatter(growth_rate_df.gdp, growth_rate_df.gdp_growth,
        xlabel = "Log GDP per capita in Initial Year",
        ylabel = "Average Annual Growth Rate (g)",
        title = "Unconditional Convergence (1979–2019)",
        label = "Countries",
        marker = (:circle, 5, :dodgerblue, stroke(0)), 
        grid = true,
        gridstyle = :dot,
        gridalpha = 0.5,
        legend = false,                     
        background_color = :white,
        foreground_color = :grey,
        size = (800, 500),                  
        margin = 5Plots.mm
    )
    
    plot!(
        growth_rate_df.log_gdp_first,
        fitted(lm(@formula(gdp_growth ~ log_gdp_first), growth_rate_df)),
        label = "Convergence Line (OLS)",
        color = :crimson,
        linewidth = 2,
        linestyle = :solid
    )
    
   
    savefig(p, "plot.png")
    
    return p
end

function regression(growth_rate_df)
  return lm(@formula(gdp_growth ~ log_gdp), growth_rate_df)
end


end # module GDPGrowth
