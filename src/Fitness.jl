function cal_mksp(schedule, sup_data)
    mksp = 0
    rs_finish_dict = Dict()
    order_finish_dict = Dict()
    for (rs_id, rs) in schedule.rs_dict
        for interval in get_interval_list(rs)
            if typeof(interval) <: WOBlock
                finish = get_finish(interval)
                if haskey(order_finish_dict, IntervalMod.IntervalMod.get_name(interval))
                    if finish> order_finish_dict[IntervalMod.get_name(interval)]
                        order_finish_dict[IntervalMod.get_name(interval)] = finish
                    end
                else
                    order_finish_dict[IntervalMod.get_name(interval)] = finish
                end
                rs_finish = get!(rs_finish_dict, rs_id, 0)
                if finish> rs_finish
                    rs_finish_dict[rs_id] = finish
                end
                if finish>mksp
                    
                    mksp = finish
                end
            end
        end
    end
    sup_data["order_finish_dict"] = order_finish_dict
    return mksp, rs_finish_dict
end
function cal_total_changeover_time(schedule)
    sum = 0
    for (rs_id, rs) in schedule.rs_dict
        for interval in get_interval_list(rs)
            if typeof(interval) <: WOBlock
                sum += get_setup_time(interval)
            end
        end
    end
    return sum
end
function sep_rs_intervals(rs, time_end)
    #先分 有沒有切到
    normal_blocks = []
    cut_block = nothing
    for interval in get_interval_list(rs)
        start = get_start(interval)
        if start > time_end #若超出了計算線 則終止挑選
            break
        else
            finish = get_finish(interval)
            if finish <= time_end #沒壓到
                push!(normal_blocks, interval)
            else #壓到的case 
                cut_block = interval
            end
        end
    end 
    return normal_blocks, cut_block
end
function count_valueble_time(normal_intervals)
    total_valuable_time = 0
    total_non_valuable_time = 0
    for interval in normal_intervals
        valuable_time = 0
        non_valuable_time = 0
        if interval isa Block
            duration = get_duration(interval)
            # non_valuable_time+=get_setup_time(interval)
            if haskey(interval.attributes.info, "rest_record")
                for rest_tuple in interval.attributes.info["rest_record"]
                     non_valuable_time+=rest_tuple[3]
                end
            end
            valuable_time = duration - get_setup_time(interval)-non_valuable_time
        elseif interval isa Forbidden
            non_valuable_time += get_duration(interval)
            # @show non_valuable_time
        end
        total_valuable_time+=valuable_time
        # @show non_valuable_time
        total_non_valuable_time+=non_valuable_time
    end
    return total_valuable_time, total_non_valuable_time
end
function deal_with_cut_block(cut_block, time_end)
    valuable_time = 0
    non_valuable_time = 0
    if cut_block isa Forbidden
        non_valuable_time+= (time_end - get_start(cut_block))
    elseif cut_block isa Block
        valuable_time += (time_end - get_start(cut_block))
        # non_valuable_time += 
        if haskey(cut_block.attributes.info, "rest_record")
            for rest_tuple in cut_block.attributes.info["rest_record"]
                if rest_tuple[2]<= time_end #若被包含住(<time_end) 則直接扣除valueable_time 並加上 non_valueable_time
                    valuable_time-=rest_tuple[3]
                    non_valuable_time+= rest_tuple[3]
                else#若剛好壓到rest的區間
                    non_valuable_time += (time_end - rest_tuple[1])
                end
            end
        end
    end
        
    return valuable_time, non_valuable_time
end
function check_rs_used(rs)
    for interval in get_interval_list(rs)
        if interval isa Block
            return true
        end
    end
    return false
end
function set_min_max_dict!(data, fit_dict)
    data["min_max_dict"] = Dict()
    setting = Dict("mksp"=>Dict("min_w"=>0.1, "max_w"=>2),
                   "total_changeover_time"=>Dict("min_w"=>0.1, "max_w"=>2),
                   "total_TD"=>Dict("min_w"=>0.1, "max_w"=>2),
                   "total_LT"=>Dict("min_w"=>0.1, "max_w"=>2)
                   )
    for (k, v) in fit_dict
        if haskey(setting, k)
            data["min_max_dict"][k]= Dict()
            data["min_max_dict"][k]["min"] = setting[k]["min_w"]*fit_dict[k]
            data["min_max_dict"][k]["max"] = setting[k]["max_w"]*fit_dict[k]
            data["min_max_dict"][k]["span"] = data["min_max_dict"][k]["max"] - data["min_max_dict"][k]["min"]
        else
            if k=="three_day_NTD"
                data["min_max_dict"]["three_day_NTD"] = Dict()
                data["min_max_dict"]["three_day_NTD"]["min"] = 0
                data["min_max_dict"]["three_day_NTD"]["max"] = length(data["WO"])
                data["min_max_dict"]["three_day_NTD"]["span"] = data["min_max_dict"]["three_day_NTD"]["max"] - data["min_max_dict"]["three_day_NTD"]["min"]
            end
            if k=="one_day_NTD"
                data["min_max_dict"]["one_day_NTD"] = Dict()
                data["min_max_dict"]["one_day_NTD"]["min"] = 0
                data["min_max_dict"]["one_day_NTD"]["max"] = length(data["WO"])
                data["min_max_dict"]["one_day_NTD"]["span"] = data["min_max_dict"]["one_day_NTD"]["max"] - data["min_max_dict"]["one_day_NTD"]["min"]
            end
        end
    end
   
end
function cal_utilization(schedule, mksp, rs_finish_dict)
    cut_period = 3

    # @show cut_period
    # time_end = cut_period*24*3600<mksp ? cut_period*24*3600 : mksp
    # time_end = mksp
    utility_sum = 0
    used_rs_count = 0 
    for (rs_id, rs) in schedule.rs_dict
        if !haskey(rs_finish_dict, rs_id)
            continue
        else
        mksp = rs_finish_dict[rs_id]
        time_end = cut_period*24*3600<mksp ? cut_period*24*3600 : mksp
        total_valuable_time = 0
        total_non_valuable_time = 0
        normal_blocks, cut_block = sep_rs_intervals(rs, time_end)
        total_valuable_time, total_non_valuable_time = count_valueble_time(normal_blocks)
        # @show total_valuable_time, total_non_valuable_time
        valuable_time, non_valuable_time = deal_with_cut_block(cut_block, time_end)
        total_valuable_time+=valuable_time
        total_non_valuable_time+=non_valuable_time
        # @show total_valuable_time, total_non_valuable_time
        molecular = total_valuable_time
        denominator = time_end - total_non_valuable_time
        utility = molecular/denominator
        # @show rs_id
        # @show utility
        utility_sum+=utility
        end
        if check_rs_used(rs)
            used_rs_count+=1
        end
    end
    
 
    avg_utility= utility_sum/used_rs_count
        return avg_utility
    end

function cal_HT(schedule, data)
    #calculate Holding Time..
    bucket_ref = data.data_dict["bucket_ref"]
    sum_HT = 0
    for (mc_id, mc) in schedule
        for interval in mc.interval_list
            if nameof(typeof(interval)) == :Bucket && interval.name != "Dummy"
                op = bucket_ref[interval.data_key]["op"]
                if op.data_dict["HOLDING_TIME"] === missing
                    continue
                else
                    HT_cons = op.data_dict["HOLDING_TIME"]
                    in_time = interval.time.in_time
                    start = interval.time.start
                    HT = start - in_time
                    sum_HT += HT > HT_cons ? (HT - HT_cons) : 0
                end
            end
        end
    end
    return sum_HT
    # return 0
end


function cal_wc_mcg_balance(schedule, data, mksp)
    function cal_wc_balance_std(mcg_mc_info, mcg_list, mksp)
        balance_diff = 0
        mcg_avg_list = []
        util_avg = 0
        for mcg_id in mcg_list
            if !haskey(mcg_mc_info, mcg_id)
                continue
            end
            mc_set = mcg_mc_info[mcg_id]
            util_sum = 0
            for mc_id in mc_set
                interval_list = schedule[mc_id].interval_list
                util = get_util(interval_list, mksp)
                util_sum += util

            end
            util_avg = util_sum / length(mc_set)
        end
        push!(mcg_avg_list, util_avg)
        std = pop_std(mcg_avg_list, mean(mcg_avg_list))

        return std

    end

    wc_mcg_dict = data.data_dict["wc_mcg_dict"]
    mcg_mc_info = data.data_dict["mcg_mc_info"]
    #計算單一工站的機群機台負荷平均平衡率
    total_balacne_score = 0
    for (wc_id, mcg_list) in wc_mcg_dict
        total_balacne_score += cal_wc_balance_std(mcg_mc_info, mcg_list, mksp)
    end
    return total_balacne_score
end

function get_util(interval_list, mksp)
    `停機時間超過mksp的不計算`
    sum_forbi = 0
    sum_working = 0
    for (idx, interval) in enumerate(interval_list)
        if interval.name == "Dummy"
            continue
        end
        #若為禁線時間： 則加總

        if typeof(interval) <: Forbidden
            # Forbidden    :             |----|
            # mksp interval:    |----|
            if interval.time.start > mksp
                continue
                # Forbidden    : |--*--|
                # mksp interval:    |----|
            elseif interval.time.start < mksp && interval.time.finish > mksp
                sum_forbi += (mksp - interval.time.start)
            else
                sum_forbi += interval.time.duration
            end
        elseif typeof(interval) <: Bucket
            sum_working += interval.time.finish - interval.time.start
        end
    end

    designed_capacity = mksp - sum_forbi
    return sum_working / designed_capacity
end

function cal_util(schedule, mksp)

    """
    cal_util
    加權稼動率(需要input)
    get_util
    從0開始，makespan結束 中間實際加工時間總和/makespan-0
    """

    util_dict = Dict()
    for (mc_id, mc) in schedule
        wᵢ = rand()
        util_dict[mc_id] = wᵢ * get_util(mc.interval_list, mksp)
    end
    return util_dict
end

function cal_NTD(schedule, data)
    orders_dict = data.data_dict["normal_orders"]
    NTD = 0
    max_op_end_dict = data.data_dict["max_op_end_dict"]
    for (order_id, order) in orders_dict
        finish_time = max_op_end_dict[order_id]
        # print("finish_time: ", order_id," = ", finish_time)
        # print("order.DD: ", order.DD)
        if finish_time > order.DD
            NTD += 1
        end
    end
    return NTD
end

function cal_lateness(schedule, sup_data)
    LT_dict = Dict()
    TD_dict = Dict()
    NTD = 0
    TD_sum = 0
    cut_period = 3
    one_day_NTD = 0 

    WO = sup_data["WO"]
    three_day_NTD = 0 
    for (order_id, finish) in sup_data["order_finish_dict"]
        if haskey(WO, order_id)
            DD = WO[order_id].info["DD"]
            if DD < 3*24*3600
                latenessᵢ = finish - DD
                LT_dict[order_id] = latenessᵢ
                if latenessᵢ>0
                    three_day_NTD += 1
                    TD_dict[order_id] = latenessᵢ
                end
            end
        end
    end
    # for (rs_id, rs) in get_rs_dict(schedule)
    #     for interval in get_interval_list(rs)
    #         if interval isa Block
    #             order = data["interval_dict"][get_key(interval)]["order"]
    #             finish_time = get_finish(interval)
    #             latenessᵢ = finish_time - order.info["DD"]
    #             # @show order_id
    #             # LT_dict[order.id] = latenessᵢ
    #             if latenessᵢ > 0
    #                 # TD_sum += latenessᵢ
    #                 # TD_dict[order.id] = latenessᵢ
    #                 NTD += 1
    #             else
    #                 # TD_dict[order.id] = 0
    #             end
    #         end
    #     end
    # end
    return LT_dict, TD_dict, TD_sum, one_day_NTD, three_day_NTD

end
function cal_tardiness(sup_data)
    supply_timeline_dict = sup_data["supply_timeline_dict"]
    for supply_info in sup_data["supply_timeline_dict"]
        
    end
end

function cal_fit(x, data)
    sup_data = decode(x, data)
    schedule = sup_data["schedule"]
    mksp, rs_finish_dict = cal_mksp(schedule, sup_data)
    # HT = Fitness.cal_HT(schedule, output_data)
    LT_dict, TD_dict, TD_sum, one_day_NTD, three_day_NTD = cal_lateness(schedule, sup_data)
    total_changeover_time = cal_total_changeover_time(schedule)
    total_LT = sum(map(x -> x[2], collect(LT_dict)))
    if length(TD_dict)>0
        total_TD = sum(map(x -> x[2], collect(TD_dict)))
    else
        total_TD = 0
    end
    avg_utilization = cal_utilization(schedule, mksp, rs_finish_dict)
    # total_balance_score = Fitness.cal_wc_mcg_balance(schedule, output_data, mksp)
    w1 = data["cfg"]["fitness"]["w1"]
    w2 = data["cfg"]["fitness"]["w2"]
    w3 = data["cfg"]["fitness"]["w3"]
    w4 = data["cfg"]["fitness"]["w4"]
    w5 = data["cfg"]["fitness"]["w5"]
    w6 = data["cfg"]["fitness"]["w6"]
    # @show w5 = data["cfg"]["para"]["w5"]

    norm_mksp = min_max_norm(data["min_max_dict"]["mksp"], mksp)
    norm_total_changeover_time = min_max_norm(data["min_max_dict"]["total_changeover_time"], total_changeover_time)
    norm_three_day_NTD = min_max_norm(data["min_max_dict"]["three_day_NTD"], three_day_NTD)
    norm_total_TD = min_max_norm(data["min_max_dict"]["total_TD"], total_TD)
    norm_total_LT = min_max_norm(data["min_max_dict"]["total_LT"], total_LT)

    # @show norm_total_TD
    # w1*norm_mksp + w2*norm_total_changeover_time + w3*(1-avg_utilization) + w4* norm_three_day_NTD + w5*norm_total_TD
    fitness = 0
    fitness += data["cfg"]["fitness"]["mksp_is_normal"]==1 ? w1*norm_mksp : w1*mksp 
    fitness += data["cfg"]["fitness"]["changeover_is_normal"]==1 ? w2*norm_total_changeover_time : w2*total_changeover_time
    fitness += w3*(1-avg_utilization)
    fitness += data["cfg"]["fitness"]["NTD_is_normal"]==1 ? w4*norm_three_day_NTD : w4*three_day_NTD
    fitness += data["cfg"]["fitness"]["TD_is_normal"]==1 ? w5*norm_total_TD : w5*total_TD
    fitness += data["cfg"]["fitness"]["LT_is_normal"]==1 ? w6*norm_total_LT : w6*total_LT
    # fitness = w1*norm_mksp + w2*norm_total_changeover_time + w3*(1-avg_utilization) + w4* three_day_NTD + w5*norm_total_TD + w6*norm_total_LT             #TODO:utility倒數後>1
    
    # @show fitness
    # 0.3*mksp + total_changeover_time + (1/avg_utilization)*350000
    # 0.3*mksp + (1/avg_utilization)*250000
    # +  (1/avg_utilization)*250000 total_changeover_time +
    # NTD * 100000 + total_changeover_time + (1/avg_utilization)*250000
    # total_LT +
    #  + 10000 * NTD + 500 * TD_sum + 1000000 * total_balance_score
    # 0.5*mksp + 10000*NTD + 500*TD_sum + 100*HT+
    # @show typeof(total_changeover_time)
    # @show typeof(avg_utilization)
    # NTD = 0
    # fitness = mksp
    fit_dict = Dict("mksp" => mksp,
                    "TD_sum" => TD_sum,
                    "one_day_NTD" => one_day_NTD,
                    "three_day_NTD"=>three_day_NTD,
                    "avg_utilization"=>avg_utilization,
                    "total_TD"=>total_TD, 
                    "total_changeover_time"=>total_changeover_time, 
                    "norm_mksp" => norm_mksp,
                    "fitness" => fitness,
                    "norm_total_changeover_time" => norm_total_changeover_time,
                    "norm_total_TD" => norm_total_TD,
                    "avg_utilization" => avg_utilization
                    )
    # fitness_set = (mksp, TD_sum, NTD)
    return fit_dict
end
function cal_fit_without_norm(x, data)
    sup_data = decode(x, data)


    schedule = sup_data["schedule"]
    mksp,rs_finish_dict = cal_mksp(schedule, sup_data)
  
    LT_dict, TD_dict, TD_sum, one_day_NTD, three_day_NTD = cal_lateness(schedule, sup_data)
    total_LT = sum(map(x -> x[2], collect(LT_dict)))
    if length(TD_dict)>0

        total_TD = sum(map(x -> x[2], collect(TD_dict)))
    else
        total_TD = 0

    end
    total_changeover_time = cal_total_changeover_time(schedule)

    avg_utilization = cal_utilization(schedule, mksp, rs_finish_dict)


    fit_dict = Dict("mksp" => mksp,
     "TD_sum" => TD_sum, "one_day_NTD" => one_day_NTD,"three_day_NTD"=>three_day_NTD,
      "avg_utilization"=>avg_utilization,
      "total_TD"=>total_TD, 
      "total_LT"=>total_LT, 
      "total_changeover_time"=>total_changeover_time)

    return fit_dict
end