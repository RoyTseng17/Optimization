
#根據encoding_dict定義的解長度 生成Nsol*Nvar的初始解   
function create_init_X(data, Nsol)
    encoding_dict = data["encoding_dict"]
    init_functions = data["init_functions"]
    #init X with size
    X = Array{Float64}(undef, Nsol, encoding_dict["length"])
    # init each sol by init_functions
    for sol = 1:Nsol
        if haskey(init_functions, string(sol))
            X[sol, :] = init_functions[string(sol)](deepcopy(data))
        else
            X[sol, :] = init_functions["policy1"](encoding_dict)#初始解生成規則按照encoding_dict設定的產生part的functions
        end
    end
   # data["origin_sol"] = X[1, :]
    return X
end
function min_max_norm(min_max_dict, x)
    norm = (x-min_max_dict["min"])/min_max_dict["span"]
return norm
end

function compare_to(v0, v1)
    return v0 <= v1
end
function find_best(F)
    max = F[1]
    best_idx = 1
    for i = 1:size(F, 1)
        if compare_to(F[i], max)
            max = F[i]
            best_idx = i
        end
    end
    return best_idx
end
