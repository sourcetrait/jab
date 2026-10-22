use (path self ../../../../../nu/mod/nutype)

# A route's model, nu/type/route/Route.nutype
const MODEL = path self ../../type/route/Route.nutype

# A route file read and held to its model; refused naming every problem
export def read [file: path]: nothing -> record {
    let route = (open --raw $file | decode utf-8 | from nuon)
    let problems = (nutype problems $route (open --raw $MODEL | decode utf-8) $MODEL)
    if ($problems | is-not-empty) {
        error make { msg: $"the route ($file) breaks its model: ($problems | str join '; ')" }
    }
    $route
}
