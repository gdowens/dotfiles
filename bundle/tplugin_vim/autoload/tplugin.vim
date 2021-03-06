" @Author:      Tom Link (micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @GIT:         http://github.com/tomtom/tplugin_vim/
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2010-09-17.
" @Last Change: 2013-01-07.
" @Revision:    250


if !exists('g:tplugin#autoload_exclude')
    " A list of repositories for which autoload is disabled when running 
    " |:TPluginScan|.
    let g:tplugin#autoload_exclude = ['tplugin']   "{{{2
endif


if !exists('g:tplugin#scan')
    " The default value for |:TPluginScan|. A set of identifiers 
    " determining the information being collected:
    "    c ... commands
    "    f ... functions
    "    p ... <plug> maps
    "    t ... filetypes
    "    h ... helptags if not available
    "    a ... autoload
    "    m ... parse vim-addon-manager metadata
    "    _ ... include _tplugin.vim files
    "    all ... all of the above
    let g:tplugin#scan = 'cfptham_'   "{{{2
endif


if !exists('g:tplugin#shallow_scan')
    let g:tplugin#shallow_scan = 'hm'   "{{{2
endif


if !exists('g:tplugin#show_helptags_errors')
    " If true, show errors when running :helptags.
    let g:tplugin#show_helptags_errors = 1   "{{{2
endif


" Write autoload information for each root directory to 
" "ROOT/_tplugin.vim".
" Search in autoload/tplugin/autoload/*.vim for prefabricated autoload 
" definitions. The file's basenames are repo names.
function! tplugin#ScanRoots(immediate, roots, shallow_roots, args) "{{{3
    let prefabs = {}
    for prefab in split(globpath(&rtp, 'autoload/tplugin/autoload/*.vim'), '\n')
        let prefab_key = fnamemodify(prefab, ':t:r')
        " TLogVAR prefab, prefab_key
        if !has_key(prefabs, prefab_key)
            let prefabs[prefab_key] = prefab
        endif
    endfor

    let awhat0 = get(a:args, 0, '')
    " echom "DBG what" string(what)

    let aroot = get(a:args, 1, '')
    if empty(aroot)
        let roots = a:roots
    else
        let roots = [fnamemodify(aroot, ':p')]
    endif

    " TLogVAR what, a:roots

    let helptags_roots = []

    for root in roots

        if empty(awhat0)
            if index(a:shallow_roots, root) != -1
                let awhat = g:tplugin#shallow_scan
            else
                let awhat = g:tplugin#scan
            endif
        else
            let awhat = awhat0
        endif
        if awhat == 'all'
            let what = ['c', 'f', 'a', 'p', 'h', 't', 'l', 'm', '_']
        else
            let what = split(awhat, '\zs')
        endif
    
        let whati = index(what, 'h')
        if whati != -1
            call add(helptags_roots, root)
            call remove(what, whati)
        endif

        " TLogVAR root
        let [is_tree, root] = s:GetRealRoot(root)
        " TLogVAR root, is_tree, isdirectory(root), len(files0)
        if !isdirectory(root)
            continue
        endif

        let [_tplugins, files0] = s:GetFiles(root, is_tree)
        let pos0 = len(root) + 1
        " TLogVAR pos0
        " TLogDBG strpart(files0[0], pos0)
        let filelist = s:GetFilelist(files0, what, pos0, is_tree)

        let out = [
                    \ '" This file was generated by TPluginScan.',
                    \ 'if g:tplugin_autoload == 2 && g:loaded_tplugin != '. g:loaded_tplugin .' | throw "TPluginScan:Outdated" | endif'
                    \ ]

        let progressbar = exists('g:loaded_tlib')
        if progressbar
            call tlib#progressbar#Init(len(filelist), 'TPlugin: Scanning '. escape(root, '%') .' %s', 20)
        else
            echo 'TPlugin: Scanning '. root .' ...'
        endif

        let whati = index(what, '_')
        if whati != -1
            for _tplugin in _tplugins
                " echom "DBG _tplugin" _tplugin
                call extend(out, readfile(_tplugin))
            endfor
            call remove(what, whati)
        endif

        let whati = index(what, 'm')
        if whati != -1
            call s:ProcessAddonInfos(out, root, 'guess')
            call remove(what, whati)
        endif
            
        let s:repos_registry = {}

        let whati = index(what, 't')
        if is_tree && whati != -1
            call remove(what, whati)

            for ftdetect in filter(copy(files0), 'strpart(v:val, pos0) =~ ''^[^\/]\+[\/]ftdetect[\/][^\/]\{-}\.vim$''')
                call add(out, 'augroup filetypedetect')
                call extend(out, readfile(ftdetect))
                call add(out, 'augroup END')
            endfor

            let ftd = {}

            let ftypes= filter(copy(files0), 'strpart(v:val, pos0) =~ ''ftplugin''')
            " TLogVAR ftypes
            let ftypes= filter(copy(files0), 'strpart(v:val, pos0) =~ ''^[^\/]\+[\/]\(ftplugin\|ftdetect\|indent\|syntax\)[\/].\{-}\.vim$''')
            " TLogVAR ftypes
            for ftfile in ftypes
                let ft = matchstr(ftfile, '[\/]\(ftplugin\|ftdetect\|indent\|syntax\)[\/]\zs[^\/.]\+')
                " TLogVAR ftfile, ft
                if empty(ft)
                    continue
                endif
                if !has_key(ftd, ft)
                    let ftd[ft] = {}
                endif
                let repo0 = matchstr(ftfile, '^.\{-}\%'. (len(root) + 2) .'c[^\/]\+')
                let repo = strpart(repo0, pos0)
                " TLogVAR ftfile, repo
                let ftd[ft][repo] = 1
                call s:PrintRegisterRepo(out, repo)
            endfor

            for [ft, repos] in items(ftd)
                " TLogVAR ft, repos
                " let repo_names = map(keys(repos), 'strpart(v:val, pos0)')
                let repo_names = keys(repos)
                call add(out, 'call TPluginFiletype('. string(ft) .', '. string(repo_names) .')')
            endfor

            let whati = index(what, 'a')
            if index(what, 'a') != -1
                let autoloads = filter(copy(files0), 'strpart(v:val, pos0) =~ ''^[^\/]\+[\/]autoload[\/].\{-}\.vim$''')
                call s:AddAutoloads(out, root, pos0, autoloads)
                call remove(what, whati)
            endif

        endif

        let s:scan_repo_done = {}
        let s:vimenter_augroups_done = {}
        try
            let fidx = 0
            let menu_done = {}
            for file in filelist
                " TLogVAR file
                if progressbar
                    let fidx += 1
                    call tlib#progressbar#Display(fidx)
                endif
                " let pluginfile = TPluginGetCanonicalFilename(file)
                if is_tree
                    let repo = matchstr(strpart(file, pos0), '^[^\/]\+\ze[\/]')
                else
                    let repo = '-'
                endif
                call s:PrintRegisterRepo(out, repo)
                let plugin = matchstr(file, '[\/]\zs[^\/]\{-}\ze\.vim$')
                " TLogVAR file, repo, plugin

                let file0 = strpart(file, pos0)

                let lines = readfile(file)

                if is_tree

                    if file0 =~ '^[^\/]\+[\/]plugin[\/][^\/]\{-}\.vim$'
                        call add(out, printf('call TPluginRegisterPlugin(%s, %s)',
                                    \ string(repo), string(plugin)))
                        if !empty(g:tplugin_menu_prefix)
                            if is_tree
                                let mrepo = escape(repo, '\.')
                            else
                                let mrepo = escape(fnamemodify(root, ':t'), '\.')
                            endif
                            let mplugin = escape(plugin, '\.')
                            if !has_key(menu_done, repo)
                                call add(out, 'call TPluginMenu('. string(mrepo .'.Add\ Repository') .', '.
                                            \ string(repo) .')')
                                call add(out, 'call TPluginMenu('. string(mrepo .'.-'. mrepo .'-') .', ":")')
                                let menu_done[repo] = 1
                            endif
                            call add(out, 'call TPluginMenu('. string(mrepo .'.'. mplugin) .', '.
                                        \ string(repo) .', '. string(plugin) .')')
                        endif
                    endif

                endif

                if !empty(what)
                    let autoload = s:ScanSource(file, repo, plugin, what, lines)
                    " TLogVAR file, repo, plugin
                    " TLogVAR keys(prefabs)
                    if has_key(prefabs, repo)
                        let autoload += readfile(prefabs[repo])
                    endif
                    if !empty(autoload)
                        let out += autoload
                    endif
                endif
            endfor
        finally
            unlet s:scan_repo_done
            unlet s:repos_registry
            if progressbar
                call tlib#progressbar#Restore()
            else
                redraw
                " echo
            endif
        endtry

        " TLogVAR out
        let outfile = TPluginFileJoin(root, g:tplugin_file .'.vim')
        call writefile(out, outfile)
        if a:immediate
            exec 'source '. TPluginFnameEscape(outfile)
        endif

    endfor

    if !empty(helptags_roots)
        call s:MakeHelpTags(helptags_roots, 'guess')
    endif
    echom "TPlugin: Finished scan"
endf


function! s:PrintRegisterRepo(out, repo) "{{{3
    if !has_key(s:repos_registry, a:repo)
        call add(a:out, printf('call TPluginRegisterRepo(%s)', string(a:repo)))
        let s:repos_registry[a:repo] = 1
    endif
endf


let s:scanner = {
            \ 'c': {
            \   'rx':  '^\s*:\?com\%[mand]!\?\s\+\(-\S\+\s\+\)*\u\k*',
            \   'fmt': {'sargs3': 'call TPluginCommand(%s, %s, %s)'}
            \ },
            \ 'f': {
            \   'rx':  '^\s*:\?fu\%[nction]!\?\s\+\zs\(s:\|<SID>\)\@![^[:space:].]\{-}\ze\s*(',
            \   'fmt': {'sargs3': 'call TPluginFunction(%s, %s, %s)'}
            \ },
            \ 'p': {
            \   'rx':  '\c^\s*:\?\zs[incvoslx]\?\(nore\)\?map\s\+\(<\(silent\|unique\|buffer\|script\)>\s*\)*<plug>[^[:space:]<]\+',
            \   'fmt': {'sargs3': 'call TPluginMap(%s, %s, %s)'}
            \ },
            \ }
let s:parameters = {}


function! s:ScanSource(file, repo, plugin, what, lines) "{{{3
    let filebase = matchstr(a:file, '[\\/][^\\/]\+[\\/]\(plugin\|ftplugin\|syntax\|indent\|autoload\)[\\/]')
    let text = join(a:lines, "\n")
    let text = substitute(text, '\n\s*\\', '', 'g')
    let lines = split(text, '\n')
    let rx = join(filter(map(copy(a:what), 'get(get(s:scanner, v:val, {}), "rx", "")'), '!empty(v:val)'), '\|')
    let out = []
    let tail = []
    let augroup0 = ''
    let include = 0
    for line in lines
        if include
            if line !~ '\S'
                let include = 0
            elseif line =~ '^\s*"\s*</VIMPLUGIN>\s*$'
                let include = 0
            else
                call add(out, line)
            endif
        else
            if !empty(tail)
                let out += tail
                let tail = []
            endif
            if line =~ '^\s*"\s*@TPluginInclude\s*$'
                let include = 1
            elseif line =~ '^\s*"\s*@TPluginInclude\s*\S'
                let out_line = substitute(line, '^\s*"\s*@TPluginInclude\s*', '', '')
                call add(out, out_line)
            elseif line =~ '^\s*"\s*@TPlugin\(Before\|After\)\s\+\S'
                let out_line = matchstr(line, '^\s*"\s*@\zsTPlugin.*$')
                call add(out, out_line)
            elseif line =~ '^\s*"\s*@TPluginMap!\?\s\+\w\{-}map\s\+.\+$'
                let maplist = matchlist(line, '^\s*"\s*@TPluginMap\(!\)\?\s\+\(\w\{-}map\(\s*<silent>\)\+\)\s\+\(.\+\)$')
                let bang = !empty(maplist[1])
                let cmd = maplist[2]
                for val in split(maplist[4], '\s\+')
                    if bang
                        if has_key(s:parameters, val)
                            let val = s:parameters[val]
                        else
                            if val =~ '^g:\w\+$'
                                if exists(val)
                                    let var = val
                                    let val = eval(val)
                                    call add(out, printf('if !exists(%s)', string(var)))
                                    call add(out, printf('    let %s = %s', var, string(val)))
                                    call add(out, 'endif')
                                else
                                    echom "TPlugin: Undefined variable ". val
                                    continue
                                endif
                            else
                                let val = eval(val)
                            endif
                            let s:parameters[var] = val
                        endif
                    endif
                    let out_line = printf("call TPluginMap(%s, %s, %s)",
                                \ string(cmd .' '. val),
                                \ string(a:repo), string(a:plugin))
                    call add(out, out_line)
                endfor
            elseif line =~ '^\s*"\s*<VIMPLUGIN\s\+id="\([^"]\+\)"\(\s\+require="\([^"]\+\)"\)\?\s*>\s*$'
                let ml = matchlist(line, '^\s*"\s*<VIMPLUGIN\s\+id="\([^"]\+\)"\(\s\+require="\([^"]\+\)"\)\?\s*>\s*$')
                let require = get(ml, 3, '')
                if !empty(require)
                    let require = substitute(require, '[[:alnum:]_]\+', 'has("&")', 'g')
                    call add(out, 'if '. require)
                    call add(tail, 'endif')
                endif
                let include = 1
            elseif line =~# '^\s*:\?aug\%[roup]\s\+\(end\|END\)\s*$'
                let augroup0 = ''
            elseif line =~# '^\s*:\?aug\%[roup]\s\+\(\S\+\)\s*$'
                let augroup0 = matchstr(line, '^\s*:\?aug\%[roup]\s\+\zs\S\+\ze\s*$')
            elseif line =~# '^\s*:\?au\%[tocmd]\s\+\(\S\+\s\+\)\?\([^,]\+,\)\{-}VimEnter\>'
                let ml = matchlist(line, '^\s*:\?au\%[tocmd]\s\+\(\S\+\s\+\)\?\([^,]\+,\)\{-}VimEnter\>\(,\S\+\)\?\s\+\(\\\s\|\S\)\+\s\+\(nested\s\+\)\?\(.\+\)$')
                let augroup = get(ml, 1, '')
                if empty(augroup)
                    let augroup = augroup0
                endif
                if !empty(augroup) && !empty(filebase) && !has_key(s:vimenter_augroups_done, augroup)
                    let cmd = 'TPluginAfter \V'. escape(filebase, '\') .' call TPluginVimEnter("'. augroup .'")'
                    call add(out, cmd)
                    let s:vimenter_augroups_done[augroup] = 1
                endif
            elseif line =~ rx
                let out_line = s:ScanLine(a:file, a:repo, a:plugin, a:what, line)
                if !empty(out_line)
                    call add(out, out_line)
                endif
            endif
        endif
    endfor
    if !empty(tail)
        let out += tail
    endif
    return out
endf


function! s:ScanLine(file, repo, plugin, what, line) "{{{3
    " TLogVAR a:file, a:repo, a:plugin, a:what, a:line
    if a:file =~ '[\/]'. a:repo .'[\/]autoload[\/]'
        let plugin = '-'
    else
        let plugin = a:plugin
    endif
    for what in a:what
        let scanner = get(s:scanner, what, {})
        if !empty(scanner)
            let m = TPluginStrip(matchstr(a:line, scanner.rx))
            if !empty(m)
                let m = substitute(m, '\s\+', ' ', 'g')
                " TLogVAR m
                if !has_key(s:scan_repo_done, what)
                    let s:scan_repo_done[what] = {}
                endif
                if has_key(s:scan_repo_done[what], m)
                    return ''
                else
                    let s:scan_repo_done[what][m] = 1
                    let fmt = scanner.fmt
                    if has_key(fmt, 'arr1')
                        return printf(fmt.arr1, string([m, a:repo, plugin]))
                    elseif has_key(fmt, 'sargs3')
                        return printf(fmt.sargs3, string(m), string(a:repo), string(plugin))
                    else
                        return printf(fmt.cargs3, escape(m, ' \	'), escape(a:repo, ' \	'), escape(plugin, ' \	'))
                    endif
                endif
            endif
        endif
    endfor
endf


function! s:GetRealRoot(rootname) "{{{3
    if a:rootname =~ '[\\/]\*$'
        return [0, TPluginGetRootDirOnDisk(a:rootname)]
    else
        return [1, a:rootname]
    endif
endf


function! s:ProcessAddonInfos(out, root, master_dir) "{{{3
    let [is_tree, root] = s:GetRealRoot(a:root)
    let pos0 = len(root) + 1
    if is_tree
        let infofiles = split(glob(TPluginFileJoin(root, '*', '*-addon-info.txt')), '\n')
        let infofiles += split(glob(TPluginFileJoin(root, '*', 'addon-info.json')), '\n')
        for info in infofiles
            let repo = fnamemodify(strpart(info, pos0), ':h')
            " TLogVAR info, repo
            call s:ParseAddonInfo(a:out, repo, info)
        endfor
    endif
endf


function! s:MakeHelpTags(roots, master_dir) "{{{3
    let tagfiles = []
    for root in a:roots
        let [is_tree, root] = s:GetRealRoot(root)
        if is_tree
            let helpdirs = split(glob(TPluginFileJoin(root, '*', 'doc')), '\n')
            for doc in helpdirs
                " TLogVAR doc
                " TLogDBG empty(glob(TPluginFileJoin(doc, '*.*')))
                if isdirectory(doc) && !empty(glob(TPluginFileJoin(doc, '*.*')))
                    let tags = TPluginFileJoin(doc, 'tags')
                    if !filereadable(tags) || s:ShouldMakeHelptags(doc)
                        " echom "DBG MakeHelpTags" 'helptags '. TPluginFnameEscape(doc)
                        let cmd = 'silent'
                        let cmd .= g:tplugin#show_helptags_errors ? ' ' : '! '
                        let cmd .= 'helptags '
                        let cmd .= TPluginFnameEscape(doc)
                        " TLogVAR cmd
                        try
                            exec cmd
                        catch /^Vim\%((\a\+)\)\=:E154/
                            if g:tplugin#show_helptags_errors
                                echohl WarningMsg
                                echom "TPlugin:" substitute(v:exception, '^Vim\%((\a\+)\)\=:E154:\s*', '', '')
                                echohl NONE
                            endif
                        endtry
                    endif
                    if filereadable(tags)
                        call add(tagfiles, tags)
                    endif
                endif
            endfor
        endif
    endfor
    if a:master_dir == 'guess'
        let master_dir = TPluginFileJoin(split(&rtp, ',')[0], 'doc')
    else
        let master_dir = a:master_dir
    endif
    if isdirectory(master_dir) && !empty(tagfiles)
        exec 'silent! helptags '. TPluginFnameEscape(master_dir)
        let master_tags = TPluginFileJoin(master_dir, 'tags')
        " TLogVAR master_dir, master_tags
        if filereadable(master_tags)
            let helptags = readfile(master_tags)
        else
            let helptags = []
        endif
        for tagfile in tagfiles
            let tagfiletags = readfile(tagfile)
            let dir = fnamemodify(tagfile, ':p:h')
            call map(tagfiletags, 's:ProcessHelpTags(v:val, dir)')
            let helptags += tagfiletags
        endfor
        call sort(helptags)
        call writefile(helptags, master_tags)
    endif
endf


function! s:ShouldMakeHelptags(dir) "{{{3
    let tags = TPluginFileJoin(a:dir, 'tags')
    let timestamp = getftime(tags)
    let create = 0
    for file in split(glob(TPluginFileJoin(a:dir, '*')), '\n')
        if getftime(file) > timestamp
            let create = 1
            break
        endif
    endfor
    return create
endf


function! s:ProcessHelpTags(line, dir) "{{{3
    let items = split(a:line, '\t')
    let items[1] = TPluginFileJoin(a:dir, items[1])
    return join(items, "\t")
endf


function! s:GetFiles(root, is_tree) "{{{3
    if a:is_tree
        let files0 = split(glob(TPluginFileJoin(a:root, '**', '*.vim')), '\n')
    else
        let files0 = split(glob(TPluginFileJoin(a:root, '*.vim')), '\n')
    endif
    " TLogVAR files0
    " TLogDBG len(files0)

    call filter(files0, '!empty(v:val) && v:val !~ ''[\/]\(\.git\|.svn\|CVS\)\([\/]\|$\)''')
    let pos0 = len(a:root) + 1
    let _tplugins = filter(copy(files0), 'strpart(v:val, pos0) =~ ''^[^\/]\+[\/]_tplugin\.vim$''')
    let excluded_plugins = map(copy(g:tplugin#autoload_exclude), 'substitute(TPluginFileJoin(a:root, v:val), ''[\/]'', ''\\[\\/]'', ''g''). ''\[\/]''')
    let exclude_rx = '\V'. join(add(excluded_plugins, '\[\\/]'. g:tplugin_file .'\(_\w\+\)\?\.vim\$'), '\|')
    " TLogVAR excluded_plugins, exclude_rx
    " TLogDBG len(files0)
    if exclude_rx != '\V'
        call filter(files0, 'v:val !~ exclude_rx')
    endif
    " TLogVAR files0
    " TLogDBG len(files0)
    return [_tplugins, files0]
endf


function! s:GetFilelist(files0, what, pos0, is_tree) "{{{3
    if !a:is_tree
        let filelist = copy(a:files0)
    else
        let filelist = filter(copy(a:files0), 'strpart(v:val, a:pos0) =~ ''^[^\/]\+[\/]plugin[\/][^\/]\{-}\.vim$''')
    endif
    " TLogDBG len(a:files0)
    " TLogDBG len(filelist)
    return filelist
endf


function! s:AddAutoloads(out, root, pos0, files) "{{{3
    " TLogVAR a:files
    for file0 in a:files
        let file = strpart(file0, a:pos0)
        let repo = matchstr(file, '^[^\/]\+')
        let def = [repo]
        let prefix = substitute(matchstr(file, '^[^\/]\+[\/]autoload[\/]\zs.\{-}\ze\.vim$'), '[\/]', '#', 'g')
        let pluginfile = substitute(file, '^[^\/]\+[\/]\zsautoload\ze[\/]', 'plugin', '')
        if index(a:files, pluginfile) != -1
            call add(def, matchstr(pluginfile, '^[^\/]\+[\/]plugin[\/]\zs.\{-}\ze\.vim$'))
        else
            call add(def, '.')
        endif
        " TLogVAR prefix, repo, file
        call add(a:out, printf('call TPluginAutoload(%s, %s)', string(prefix), string(def)))
    endfor
endf


function! s:ParseAddonInfo(out, repo, file) "{{{3
    let src = join(readfile(a:file), ' ')
    if s:VerifyIsJSON(src)
        let dict = eval(src)
        let deps = []
        for [name, def] in items(get(dict, 'dependencies', {}))
            let url = get(def, 'url', '')
            if url == 'git://github.com/tomtom/'. name .'_vim.git'
                call add(deps, name .'_vim')
            else
                call add(deps, name)
            endif
        endfor
        if !empty(deps)
            call add(a:out, 'call TPluginDependencies('. string(a:repo) .', '. string(deps) .')')
        endif
    else
        echohl WarningMsg
        echom "TPlugin: invalid json:" a:file
        echohl NONE
    endif
endf


function! s:VerifyIsJSON(s)
    if exists('*vam#VerifyIsJSON')
        return vam#VerifyIsJSON(a:s)
    else
        """ Taken from vim-addon-manager
        " You must allow single-quoted strings in order for writefile([string()]) that 
        " adds missing addon information to work
        let scalarless_body = substitute(a:s, '\v\"%(\\.|[^"\\])*\"|\''%(\''{2}|[^''])*\''|true|false|null|[+-]?\d+%(\.\d+%([Ee][+-]?\d+)?)?', '', 'g')
        return scalarless_body !~# "[^,:{}[\\] \t]"
    endif
endf


