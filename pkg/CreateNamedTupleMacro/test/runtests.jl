
using CreateNamedTupleMacro
using Test

mynt = @NT begin
    x = 3
    y = 2x
end

@test mynt == (; x=3, y=6)
