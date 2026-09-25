if exists("b:current_syntax")
  finish
endif

syntax region coqString start=+"+ skip=+\\"+ end=+"+ contains=@Spell
syntax keyword coqTodo contained TODO FIXME XXX
syntax region coqComment start="(\*" end="\*)" contains=coqComment,coqTodo,@Spell

highlight default link coqString String
highlight default link coqComment Comment
highlight default link coqTodo Todo

let b:current_syntax = "coq"
