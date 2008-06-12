" author: Yuichi Tateno
" MIT Licence
"
if exists("g:loaded_as3importcomp")
  finish
endif
let g:loaded_as3importcomp = 1

let s:ASdict = {}

let s:inited = 0
function! s:init()
  if(s:inited == 0)
    let s:inited = 1
    if(exists('g:as3importcomp_dictfile'))
      let filepath = g:as3importcomp_dictfile
    else
      let filepath = $HOME . '/.vim/dict/as3packagelist'
    endif
    if filereadable(filepath)
      for line in readfile(filepath, "b")
        let a  = split(line, ' ', 2)
        if (len(a) == 2)
          if (!has_key(s:ASdict, a[0]))
            let s:ASdict[a[0]] = []
          endif
          call add(s:ASdict[a[0]], a[1])
        endif
      endfor
    else
      echoerr filepath . 'is not found'
    endif
  endif
endfunction

let s:AS3PackageCompletePackageSelectString = ''

function! AS3ImportCompleteWord(word)
  call s:init()
  let imports = []
  if (has_key(s:ASdict, a:word))
    call extend(imports, s:ASdict[a:word])
  endif
  call extend(imports, s:getImportByTags(a:word))
  call s:AS3PackageCompleteView(imports)
endfunction

function! AS3ImportCompleteCWord()
  let word = expand('<cword>')
  call AS3ImportCompleteWord(word)
endfunction

function! AS3ImportCompleteLine(lineStr)
  let ary = []
  let re = '[^a-z0-9_]\(\u[A-Za-z0-9_]*\)'
  call substitute(a:lineStr, re, '\= add(ary, submatch(1))', 'g')
  for m in ary
    call AS3ImportCompleteWord(m)
  endfor
endfunction

function! AS3ImportCompleteCline()
  call AS3ImportCompleteLine(getline('.'))
endfunction

"let s:importMatched = 1
function! s:FindInsertLineIndex(bline)
  let s:importMatched = 0
  let regex = 'import\s\+'
  let classRegex = 'class\s\+'
  let importIndex = -1
  let lineIndex = 0

  for line in a:bline
    let lineIndex += 1
    if(match(line, regex) >= 0)
      let importIndex = lineIndex
    endif
    if(match(line, classRegex) >= 0)
      if (importIndex >= 0) 
        "let s:importMatched = 1
        return importIndex + 1
      else
        "let s:importMatched = 0
        return lineIndex
      endif
    endif
  endfor

  return max([importIndex + 1, 1])
  "return -1
endfunction

function! s:MatchCheck(import)
  " TODO: not . escape
  let regex = 'import\s\+' . a:import . ';'
  let package_regex = 'package\s\+' . substitute(a:import, '\(.*\)\.[A-Z].\{-}$', "\\1", '') . '[^\.]'
  if search(regex, 'n', 0)
    return 1
  elseif search(package_regex, 'n', 0)
    return 1
  else
    return 0
  endif
endfunction

let s:iEnterPos = -1
let s:iLeavePos = -1
let s:autoComplete = 0

function! s:iEnter()
  if(s:autoComplete)
    let s:iEnterPos = line('.')
  endif
endfunction

function! s:iLeave()
  if(s:autoComplete)
    let iLeavePos = line('.')
    if (s:iEnterPos >= 0)
      if(s:iEnterPos > iLeavePos)
        let st = iLeavePos
        let ed = s:iEnterPos
      else
        let st = s:iEnterPos
        let ed = iLeavePos
      endif
      call s:completeLines(st, ed)
    endif
  endif
endfunction

function! s:getImportByTags(name)
  let matchlist = taglist('^\C' . a:name . '$')
  let res = []
  for m in matchlist
    if m['kind'] == 'C' || m['kind'] == 'I'
      if match(m['filename'], '/') != 0
        let s:import = s:importFormat(m['filename'])
        " call add(res, s:importFormat(m['filename']))
        if strlen(s:import) && s:import[0] != '.'
          call add(res, s:importFormat(s:import))
        endif
      else
        let s:import = s:getImportByTagfiles(m['filename'])
        if strlen(s:import) && s:import[0] != '/'
          call add(res, s:importFormat(s:import))
        endif
      endif
    endif
  endfor
  return res
endfunction

function! s:importFormat(path)
  return substitute(substitute(a:path, '/', '.', 'g'), '\.\(as\|mxml\)', '', '')
endfunction

function! s:getImportByTagfiles(filename)
    let tfs = tagfiles()
    for tagfile in tagfiles()
      let path = escape(substitute(tagfile, '[^/]\+$','',''), '/')
      if match(a:filename, path) == 0
        return substitute(a:filename, path, '', '')
      endif
    endfor
    return ''
endfunction

function! s:completeLines(st, ed)
  let lines = []
  let st = a:st
  while st <= a:ed
    call add(lines, getline(st))
    let st += 1
  endwhile
  for line in lines
    call AS3ImportCompleteLine(line)
  endfor
endfunction

function! AS3ImportAutoComplete()
  let s:autoComplete = 1
endfunction

function! AS3ImportNoAutoComplete()
  let s:autoComplete = 0
endfunction

function! AS3ImportCompleteRange() range
  call s:completeLines(a:firstline, a:lastline)
endfunction

function! s:AS3PackageCompleteView(arg) " List
  if len(a:arg) == 0
    return
  elseif len(a:arg) == 1
    call s:AS3PackageCompletePackage(a:arg[0])
    return
  endif

  call s:AS3PackageCompleteViewBufShow()
  setlocal modifiable
  call s:AS3PackageCompleteRenderList(a:arg)
  execute ':res ' . len(a:arg)
  call s:AS3PackageCompleteKeymapList()

  augroup AS3PackageComplete_LocalAutoCommand
      autocmd!
      " autocmd BufLeave     <buffer>        call feedkeys(<SID>OnBufLeave()    , 'n')
      autocmd BufLeave     <buffer>        call <SID>OnBufLeave()
  augroup END

  setlocal nomodifiable
endfunction

"let s:AS3PackageCompleteBufNo = -1
function! s:AS3PackageCompleteViewBufShow()
  if exists('s:buf_nr')
    execute 'buffer ' . s:buf_nr
    setlocal modifiable
    delete _
  else
    execute '1new [AS3PackageComplete]'
    let s:buf_nr = bufnr('%')
    
    "setlocal nomodifiable
    "setlocal nobuflisted 
    "setlocal nonumber 
    "setlocal noswapfile
    "setlocal buftype=nofile
    "setlocal bufhidden=wipe
    "setlocal noshowcmd
    "setlocal nowrap 

    setlocal nomodifiable
    setlocal bufhidden=wipe
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted

    "execute 'file ' . '[AS3PackageComplete]'
  end
endfunction

function! s:AS3PackageCompleteKeymapList()
  noremap <buffer> <silent> <CR> :call <SID>AS3PackageCompleteViewBufSelect()<CR>
  noremap <buffer> <silent> m :call <SID>AS3PackageCompleteViewBufSelect()<CR>
  noremap <buffer> <silent> q :call <SID>AS3PackageCompleteViewBufClose()<CR>
  noremap <buffer> <silent> <C-C> :call <SID>AS3PackageCompleteViewBufClose()<CR>
endfunction

function! s:AS3PackageCompleteRenderList(arg)
  setlocal modifiable
  silent! %g/\v.?/d_
  for line in a:arg
    silent! put= line
  endfor
  call cursor(1, 1)
  delete _
endfunction

function! s:AS3PackageCompleteViewBufClose()
  "let s:AS3PackageCompleteBufNo = -1
  close
endfunction

function! <SID>OnBufLeave()
    " resume autocomplpop.vim
    unlet s:buf_nr
    quit " Quit when other window clicked without leaving a insert mode.
endfunction

function! s:AS3PackageCompleteViewBufSelect()
  let pkg = getline('.')
  call s:AS3PackageCompleteViewBufClose()
  if (strlen(pkg) > 0)
    call s:AS3PackageCompletePackage(pkg)
  endif
endfunction

function! s:AS3PackageCompletePackage(arg)
  let import = a:arg
  let bline = getbufline(bufnr('%'), 1, "$")

  if s:MatchCheck(import)
    " exist import line
    return 0
  endif

  let lineIndex = s:FindInsertLineIndex(bline) - 1
  if (lineIndex < 0)
    return 0
  endif

  "if s:importMatched == 0
  let indentVal = max([0, indent(lineIndex-1)])
  if indentVal == 0
    let indentVal += &shiftwidth
  endif

  call append(lineIndex, repeat(' ', indentVal) . 'import ' . import . ';')
endfunction

" autocmd! InsertEnter *.as,*.mxml call s:iEnter()
" autocmd! InsertLeave *.as,*.mxml call s:iLeave()
