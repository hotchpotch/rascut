
if exists("g:rascut_error_observe")
   finish
endif

let g:rascut_error_observe = 1

let s:nowCmdwin = 0

function! s:RascutErrorObserve()
  autocmd CursorMoved * call s:OnCursorMoved()
  autocmd CursorMovedI * call s:OnCursorMoved()
  autocmd CmdwinEnter * call s:OnCmdwinEnter()
  autocmd CmdwinLeave * call s:OnCmdwinLeave()

  call s:OnCursorMoved()
  silent lopen 1
endfunction

function! s:OnCursorMoved()
  if s:nowCmdwin == 0
    lgetfile
  end
endfunction

function! s:OnCmdwinEnter()
  let s:nowCmdwin = 1
endfunction

function! s:OnCmdwinLeave()
  let s:nowCmdwin = 0
endfunction

command -nargs=0 RascutErrorObserve :call s:RascutErrorObserve()
