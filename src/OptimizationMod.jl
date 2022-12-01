module OptimizationMod
using IntervalMod
using ResourceMod
using DecodeMod
export 
    #Algorithm Functions 定義演算通用的Functions
    create_init_X,
    compare_to,
    min_max_norm,
    find_best,
    #Algorithms 定義演算法Structs, 
    SSO,
    #Fitness
    cal_mksp,
    cal_total_changeover_time,
    sep_rs_intervals,
    count_valueble_time,
    deal_with_cut_block,
    check_rs_used,
    set_min_max_dict!,
    cal_utilization,
    cal_HT,
    cal_wc_mcg_balance,
    get_util,
    cal_util,
    cal_NTD,
    cal_lateness,
    cal_tardiness,
    cal_fit,
    cal_fit_without_norm
    include("./AlgorithmFunctions.jl")
    include("./Algorithms.jl")
    include("./Fitness.jl")
end # module
