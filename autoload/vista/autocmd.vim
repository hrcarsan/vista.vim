" Copyright (c) 2019 Liu-Cheng Xu
" MIT License
" vim: ts=2 sw=2 sts=2 et

let s:registered = []
let s:update_timer = -1

function! s:ClearOtherEvents(group) abort
  for augroup in s:registered
    if augroup != a:group && exists('#'.augroup)
      execute 'autocmd!' augroup
    endif
  endfor
endfunction

function! s:OnBufEnter(bufnr, fpath) abort
  if !exists('g:vista')
    return
  endif

  call s:GenericAutoUpdate(a:bufnr, a:fpath)
endfunction

function! s:GenericAutoUpdate(bufnr, fpath) abort
  if vista#ShouldSkip()
    return
  endif

  let [bufnr, winnr, fname] = [a:bufnr, winnr(), expand('%')]

  call vista#source#Update(bufnr, winnr, fname, a:fpath)

  call s:ApplyAutoUpdate(a:fpath)
endfunction

function! s:AutoUpdateWithDelay(bufnr, fpath) abort
  if !exists('g:vista')
    return
  endif

  if s:update_timer != -1
    call timer_stop(s:update_timer)
    let s:update_timer = -1
  endif

  let g:vista.on_text_changed = 1
  let s:update_timer = timer_start(
        \ g:vista_update_on_text_changed_delay,
        \ { -> s:GenericAutoUpdate(a:bufnr, a:fpath)}
        \ )
endfunction

" Every time we call :Vista foo, we should clear other autocmd events and only
" keep the current one, otherwise there will be multiple autoupdate events
" interacting with other.
function! vista#autocmd#Init(group_name, AUF) abort

  call s:ClearOtherEvents(a:group_name)

  if index(s:registered, a:group_name) == -1
    call add(s:registered, a:group_name)
  endif

  let s:ApplyAutoUpdate = a:AUF

  if exists('#'.a:group_name)
    if len(split(execute('autocmd '.a:group_name), '\n')) > 1
      return
    endif
  endif

  execute 'augroup' a:group_name
    autocmd!

    " vint: -ProhibitAutocmdWithNoGroup
    autocmd WinEnter,WinLeave __vista__ call vista#statusline#RenderOnWinEvent()

    " BufReadPost is needed for reloading the current buffer if the file
    " was changed by an external command;
    "
    " CursorHold and CursorHoldI event have been removed in order to
    " highlight the nearest tag automatically.
    "autocmd BufWritePost,BufReadPost, *
          "\ call s:GenericAutoUpdate(+expand('<abuf>'), fnamemodify(expand('<afile>'), ':p'))

    autocmd BufWritePost,BufReadPost, *
          \ call s:AutoUpdateWithDelay(+expand('<abuf>'), fnamemodify(expand('<afile>'), ':p'))

    " autocmd BufEnter *
    "      \ call s:OnBufEnter(+expand('<abuf>'), fnamemodify(expand('<afile>'), ':p'))

    autocmd BufEnter *
          \ call s:AutoUpdateWithDelay(+expand('<abuf>'), fnamemodify(expand('<afile>'), ':p'))


    if g:vista_update_on_text_changed
      autocmd TextChanged,TextChangedI *
            \ call s:AutoUpdateWithDelay(+expand('<abuf>'), fnamemodify(expand('<afile>'), ':p'))
    endif
  augroup END
endfunction


function! vista#autocmd#InitMOF() abort
  augroup VistaMOF
    autocmd!
    autocmd CursorMoved * call vista#cursor#FindNearestMethodOrFunction()
  augroup END
endfunction
