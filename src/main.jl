using GDPGrowth
using ArgParse
using GLM
using CSV
using DataFrames
using Printf

using Plots

function parse_args_custom(args)
  s = ArgParseSettings()
  @add_arg_table! s begin
    "--countries"
    help = "Comma-separated country codes, e.g. --countries=USA,DEU,GBR"
    arg_type = String
    "--countries-file"
    help = "Path to a file with comma or newline separated country codes"
    arg_type = String
    "--year"
    help = "Start and end year, e.g. --year=2010,2020"
    arg_type = String
    required = true
  end
  return parse_args(args, s)
end

function parse_countries_file(filepath::String)::Vector{String}
  return open(filepath, "r") do f
    content = read(f, String)
    return filter(!isempty, strip.(split(content, r"[,\n]+")))
  end
end

function resolve_countries(parsed::Dict)::Vector{String}
  has_list = !isnothing(parsed["countries"])
  has_file = !isnothing(parsed["countries-file"])

  if has_list && has_file
    error("Provide either --countries or --countries-file, not both")
  elseif has_list
    return filter(!isempty, strip.(split(parsed["countries"], ",")))
  elseif has_file
    return parse_countries_file(parsed["countries-file"])
  else
    error("Either --countries or --countries-file is required")
  end
end

function regression_to_dataframe(model)::DataFrame
  ct = coeftable(model)
  df = DataFrame(
    term=ct.rownms,
    coefficient=ct.cols[1],
    std_error=ct.cols[2],
    t_statistic=ct.cols[3],
    p_value=ct.cols[4],
  )
  df[!, :r2] .= r2(model)
  return df
end

function print_regression_summary(model, df::DataFrame)
  println("\n", "="^52)
  println("  Regression Results")
  println("="^52)
  @printf "  %-20s %10s %10s %8s\n" "Term" "Coef" "Std Err" "p-value"
  println("-"^52)
  for row in eachrow(df)
    sig = row.p_value < 0.001 ? "***" :
          row.p_value < 0.01 ? "**" :
          row.p_value < 0.05 ? "*" : ""
    @printf "  %-20s %10.4f %10.4f %7.4f %s\n" row.term row.coefficient row.std_error row.p_value sig
  end
  println("="^52)
  @printf "  R²: %.4f\n" r2(model)
  println("="^52, "\n")
  println("  Significance: *** p<0.001  ** p<0.01  * p<0.05")
  return println()
end

function (@main)(args)
  parsed = parse_args_custom(args)
  countries = resolve_countries(parsed)
  years = parse.(Int, split(parsed["year"], ","))
  start_year, end_year = years[1], years[2]

  gdp_per_c_df = get_gdp_per_capita_dataframe()
  gdf = generate_growth_dataframe(gdp_per_c_df, start_year, end_year; included_countries=countries)
  plot_growth_rates(gdf)
  savefig("plot.png")

  regression_result = regression(gdf)
  df = regression_to_dataframe(regression_result)

  print_regression_summary(regression_result, df)

  CSV.write("regression_results.csv", df)
  @info "Regression R²: $(r2(regression_result))"
  @info "Results saved to regression_results.csv"

  return nothing
end
