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
select_year_period(df, period_start, period_end) = df[period_start .≤ df.year .≤ period_end, :]
select_countries(df, countries) = filter(:code => x -> x ∈ countries, df)

function growth_rate(df, start_year, end_year, country)
    start_value = first(df[df.year .== start_year, country])
    end_value = first(df[df.year .== end_year, country])
    return (log(end_value) - log(start_value)) / (end_year - start_year)
end

function countries_with_data(df, year1, year2)
    codes = unique(df.code)

    return filter(
        code -> begin
            years = df[df.code .== code, :year]
            year1 in years && year2 in years
        end, codes
    )
end

function generate_growth_dataframe(gdp_per_df, start_year, end_year; included_countries = nothing)

    countries = if isnothing(included_countries)
        countries_with_data(gdp_per_df, start_year, end_year)
    else
        intersect(countries_with_data(gdp_per_df, start_year, end_year), included_countries)
    end

    gdp_per_c_pivot = to_long_form(gdp_per_df)

    return DataFrame(
        countries = countries,
        gdp_growth = [growth_rate(gdp_per_c_pivot, start_year, end_year, c) for c in countries],
        gdp = [first(gdp_per_c_pivot[gdp_per_c_pivot.year .== start_year, c]) for c in countries],
        log_gdp = [log(first(gdp_per_c_pivot[gdp_per_c_pivot.year .== start_year, c])) for c in countries]
    )
end

function plot_growth_rates(growth_rate_df)
    p = scatter(
        growth_rate_df.log_gdp, growth_rate_df.gdp_growth,
        xlabel = "Log GDP per capita in Initial Year (1979)",
        ylabel = "Average Annual Growth Rate (g)",
        title = "Global Income Convergence (1979–2019)",
        titlefont = font(13, :black, "Helvetica-Bold"),
        titlelocation = :left,
        label = "Countries",
        marker = (:circle, 4, :darkgrey, stroke(0)),
        grid = true,
        gridstyle = :dot,
        gridalpha = 0.5,
        legend = false,
        background_color = :white,
        foreground_color = :black,
        size = (800, 500),
        margin = 5Plots.mm
    )

    ols_model = lm(@formula(gdp_growth ~ log_gdp), growth_rate_df)
    intercept_val = coef(ols_model)[1]
    slope_val = coef(ols_model)[2]


    x_min = minimum(growth_rate_df.log_gdp)
    x_max = maximum(growth_rate_df.log_gdp)

    line_x = [x_min, x_max]
    line_y = [intercept_val + slope_val * x_min, intercept_val + slope_val * x_max]


    plot!(
        line_x,
        line_y,
        label = "Convergence Line (OLS)",
        color = :maroon,
        linewidth = 2.5,
        linestyle = :solid
    )


    return p
end

function regression(growth_rate_df)
    return lm(@formula(gdp_growth ~ log_gdp), growth_rate_df)
end


end # module GDPGrowth
