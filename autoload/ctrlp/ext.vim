" =============================================================================
" File:          autoload/ctrlp/ext.vim
" Description:   Simple extension to test things
" Author:        humus <github.com/humus"
" =============================================================================

" if exists('g:loaded_ctrlp_ext') && g:loaded_ctrlp_ext
"     finish
" endif

if !exists('g:loaded_ctrlp_ext')
  call add(g:ctrlp_ext_vars, {
      \ 'init': 'ctrlp#ext#init()',
      \ 'accept': 'ctrlp#ext#accept',
      \ 'lname': 'simple extension',
      \ 'sname': 'simpleext',
      \ 'type': 'line',
      \})
endif

let g:loaded_ctrlp_ext = 1

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

fun! ctrlp#ext#id() "{{{
  return s:id
endfunction "}}}

let s:dict_functions = {}

fun! s:dict_functions.server_communicate(type)
  let response = javacomplete#server#Communicate('-E', a:type, '')
  let dict = eval(response)[a:type]
  let dict = javacomplete#util#Sort(dict)
  return dict
endfunction "}}}

fun! s:dict_functions.ctrlp_exit()
  call ctrlp#exit()
endfunction "}}}

fun! ctrlp#ext#init() "{{{
  let type='java.util.ArrayList<Integer>'
  let response = s:dict_functions.server_communicate(type)
  let list = s:DoGetMemberList(response, 0)
  return map(copy(list), 'v:val["word"] . "#" . v:val["menu"]')
endfunction "}}}

fun! ctrlp#ext#accept(type, str) "{{{
  call s:dict_functions.ctrlp_exit()
  execute 'normal! a'.a:str
endfunction "}}}

function! s:DoGetMemberList(ci, outputkind)
  " call s:Log("get member list. outputkind: ". a:outputkind)

  let kind = a:outputkind
  let outputkind = a:outputkind
  if type(a:ci) != type({}) || a:ci == {}
    return []
  endif

  let s = ''
  if kind == 11
    let tmp = javacomplete#collector#DoGetClassInfo('this')
    if a:ci.name && tmp.name == a:ci.name
      let outputkind = 15
    endif
  endif

  let members = javacomplete#complete#complete#SearchMember(a:ci, '', 1, kind, 1, outputkind, kind == 2)
  let members[1] = s:UniqDeclaration(members[1])

  let s .= kind == 11 ? "{'kind': 'C', 'word': 'class', 'menu': 'Class'}," : ''

  " add accessible member types
  if kind / 10 != 0
    " Use dup here for member type can share name with field.
    for class in members[0]
      "for class in get(a:ci, 'classes', [])
      let v = get(g:JavaComplete_Cache, class, {})
      if v == {} || v.flags[-1:]
        let s .= "{'kind': 'C', 'word': '" . substitute(class, a:ci.name . '\.', '\1', '') . "','dup':1},"
      endif
    endfor
  endif

  if kind != 13
    let fieldlist = []
    let sfieldlist = []
    for field in members[2]
      "for field in get(a:ci, 'fields', [])
      if javacomplete#util#IsStatic(field['m'])
        if kind != 1
          call add(sfieldlist, field)
        endif
      elseif kind / 10 == 0
        call add(fieldlist, field)
      endif
    endfor

    let methodlist = []
    let smethodlist = []
    for method in members[1]
      if javacomplete#util#IsStatic(method['m'])
        if kind != 1
          call add(smethodlist, method)
        endif
      elseif kind / 10 == 0
        call add(methodlist, method)
      endif
    endfor

    if kind / 10 == 0
      let s .= s:DoGetFieldList(fieldlist)
      let s .= s:DoGetMethodList(methodlist, outputkind)
    endif
    let s .= s:DoGetMethodList(smethodlist, outputkind, kind == 12)
    let s .= s:DoGetNestedList(members[3])

    let s = substitute(s, '\<' . a:ci.name . '\.', '', 'g')
    let s = substitute(s, '\<\(public\|static\|synchronized\|transient\|volatile\|final\|strictfp\|serializable\|native\)\s\+', '', 'g')
  else
    let s .= s:DoGetNestedList(members[3])
  endif
  return eval('[' . s . ']')
endfunction

function! s:UniqDeclaration(members)
  let declarations = {}
  for m in a:members
    let declarations[javacomplete#util#CleanFQN(m.d)] = m
  endfor
  let result = []
  for k in keys(declarations)
    call add(result, declarations[k])
  endfor
  return result
endfunction

function! s:DoGetMethodList(methods, kind, ...)
  let paren = a:0 == 0 || !a:1 ? '(' : (a:1 == 2) ? ' = ' : ''

  let abbrEnd = ''
  let methodNames = map(copy(a:methods), 'v:val.n')

  let useFQN = javacomplete#UseFQN()
  let s = ''
  let origParen = paren
  for method in a:methods
    if !useFQN
      let method.d = javacomplete#util#CleanFQN(method.d)
    endif
    let paren = origParen
    if paren == '('
      if count(methodNames, method.n) == 1
        if !has_key(method, 'p')
          let paren = '()'
        endif
      endif
    endif
    let s .= "{'kind':'" . (javacomplete#util#IsStatic(method.m) ? "M" : "m") . "','word':'" . s:GenWord(method, a:kind, paren) . "','abbr':'" . method.n . abbrEnd . "','menu':'" . method.d . "','dup':'1'},"
  endfor

  return s
endfunction

function! s:DoGetFieldList(fields)
  let s = ''
  let useFQN = javacomplete#UseFQN()
  for field in a:fields
    if !has_key(field, 't')
      continue
    endif
    if type(field.t) == type([])
      let fieldType = field.t[0]
      let args = ''
      for arg in field.t[1]
        let args .= arg. ','
      endfor
      if len(args) > 0
        let fieldType .= '<'. args[0:-2]. '>'
      endif
    else
      let fieldType = field.t
    endif
    if !useFQN
      let fieldType = javacomplete#util#CleanFQN(fieldType)
    endif
    let s .= "{'kind':'" . (javacomplete#util#IsStatic(field.m) ? "F" : "f") . "','word':'" . field.n . "','menu':'" . fieldType . "','dup':1},"
  endfor
  return s
endfunction

function! s:DoGetNestedList(classes)
  let s = ''
  let useFQN = s:UseFQN()
  for class in a:classes
    if !useFQN
      let fieldType = javacomplete#util#CleanFQN(class.m)
    else
      let fieldType = class.m
    endif
    let s .= "{'kind':'C','word':'". class.n . "','menu':'". fieldType . "','dup':1},"
  endfor

  return s
endfunction

function! s:UseFQN()
  return get(g:, 'JavaComplete_UseFQN', 0)
endfunction

function! s:GenWord(method, kind, paren)
  if a:kind == 14
    return javacomplete#util#GenMethodParamsDeclaration(a:method). ' {'
  else
    return a:method.n
  endif
endfunction

fun! ctrlp#ext#dict_functions() "{{{
  return s:dict_functions
endfunction "}}}
