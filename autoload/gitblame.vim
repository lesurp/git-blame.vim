let s:save_cpo = &cpo
set cpo&vim

let g:GBlameVirtualTextEnable = 1
let g:GBlameVirtualTextPrefix = get(g:, 'GBlameVirtualTextPrefix', "    > ")

function! s:system(str, ...)
  let command = a:str
  let input = a:0 >= 1 ? a:1 : ''

  if a:0 == 0
    let output = system(command)
  else
    let output =  system(command, input)
  endif

  return output
endfunction

function! gitblame#commit_summary(file, line)
    let git_blame = split(s:system('cd "$(dirname "'.a:file.'")"; git --no-pager blame "$(basename "'.a:file.'")" -L "$(basename "'.a:line.'")",+1 --porcelain'), "\n")
    let l:shell_error = v:shell_error
    if l:shell_error && ( git_blame[0] =~# '^fatal: Not a git repository' || git_blame[0] =~# '^fatal: cannot stat path' )
        return {'error': 'Not a git repository'}
    elseif l:shell_error
        return {'error': 'Unhandled error: '.git_blame[0]}
    endif

    let commit_hash = matchstr( git_blame[0], '^\^*\zs\S\+' )
    if commit_hash =~# '^0\+$'
        " not committed yet
        return {'error': 'Not Committed yet'}
    endif

    let summary = ''
    for line in git_blame
        if line =~# '^summary '
            let summary = matchstr(line, '^summary \zs.\+$')
            break
        endif
    endfor

    let author = matchstr(git_blame[1], 'author \zs.\+$')
    let author_mail = matchstr(git_blame[2], 'author-mail \zs.\+$')
    let timestamp = matchstr(git_blame[3], 'author-time \zs.\+$')
    let author_time = strftime("%Y-%m-%d %X", timestamp)

    return {'author':author, 'author_mail': author_mail, 'author_time': author_time, 'commit_hash': commit_hash, 'summary': summary, 'timestamp': timestamp }
endfunction

" s <=> script local
let s:was_set = 0
function! gitblame#echo()
    " delete previous virtual line if it was set
    if s:was_set
        let s:was_set = 0
        call nvim_buf_clear_namespace(s:buffer, s:ns, 0, -1)
    endif

    let l:blank = ' '
    let l:file = expand('%')
    let l:line = line('.')
    let l:gb = gitblame#commit_summary(l:file, l:line)
    if has_key(l:gb, 'error')
        let l:echoMsg = '['.l:gb['error'].']'
    else
        let l:echoMsg = '['.l:gb['commit_hash'][0:8].'] '.l:gb['summary'] .l:blank .l:gb['author_mail'] .l:blank .l:gb['author'] .l:blank .'('.l:gb['author_time'].')'
    endif

    " changes flag so we clear this line next time we call the echo method
    let s:was_set = 1
    let s:ns = nvim_create_namespace('gitBlame')
    let l:line = line('.')
    let s:buffer = bufnr('')
    call nvim_buf_set_virtual_text(s:buffer, s:ns, l:line-1, [[g:GBlameVirtualTextPrefix.l:echoMsg, 'GBlameMSG']], {})
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
