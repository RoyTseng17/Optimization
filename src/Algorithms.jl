abstract type Algorithm end

struct SSO <: Algorithm
    data::Dict
    objects::Dict
    init!::Function
    update!::Function
    output::Function
    optimize!::Function
    SSO(data, init!, update!, output, optimize!) = new(data,  Dict(), init!, update!, output, optimize!)
end