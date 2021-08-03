# Used by "mix format"

locals_without_parens = [defr: 2, defrp: 2, let: 1 , tell: 1]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
