#
# Add suport for telling ConEmu about the current directory
#
function conemu_working_directory_support {
    # For environments that support ANSI escape sequences
    CONEMU_PS1="\[\e]9;9;\"\w\"\007\e]9;12\007\]"
    if [[ -n "${ConEmuPID}" ]]; then
        if [[ $PS1 != *"$CONEMU_PS1"* ]]; then
            PS1=$PS1$CONEMU_PS1
        fi
    fi

    # For environments that don't support ANSI escape sequences
    # Don't even try for WSL - it can't work
    CONEMU_STORE="ConEmuC -StoreCWD"
    if ! grep -q Microsoft /proc/version; then
        if [[ -n "${ConEmuPID}" ]]; then
            if [[ $PROMPT_COMMAND != *"$CONEMU_STORE"* ]]; then
                PROMPT_COMMAND=$CONEMU_STORE';'$PROMPT_COMMAND
            fi
        fi
    fi
}

conemu_working_directory_support

#
# The Default sq-alter-ps1 script breaks working directory support.
# So instead disable that script and subsitute a similar prompt
#
function __sq_prompt_prefix {
    if [ -n "$SQ_TOOLCHAIN_FOLDER" ]; then
        SQ_PROMPT_PREFIX="sq:${project}:${architecture} "
    else
        SQ_PROMPT_PREFIX=""
    fi
}

if [[ $PROMPT_COMMAND != *"__sq_prompt_prefix"* ]]; then
    PROMPT_COMMAND="__sq_prompt_prefix;$PROMPT_COMMAND"
fi

export SQ_ALTER_PS1=false

if [[ $PS1 != *"\$SQ_PROMPT_PREFIX"* ]]; then
    PS1='\[\e[0;35m\]'"\$SQ_PROMPT_PREFIX"'\[\e[0m\]'$PS1
fi

#
# Example of how to do extra customization of the prompt
# Enable by placing "fancy_seeq_prompt" in bashrc
#
function fancy_seeq_prompt {
    SQ_ALTER_PS1=false

    __parse_git_branch() {
        git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
    }

    __parse_git_root() {
        local GIT_ROOT=$(git rev-parse --show-toplevel 2> /dev/null)
        if [ -z "$GIT_ROOT" ]
        then
           echo -n ""
        elif [[ $GIT_ROOT -ef $PWD ]]
        then
           echo -n " <*>"
        else
           echo -n " <*${GIT_ROOT##*/}>"
        fi
    }

    function __fancy_seeq_prompt_command {
        local EXIT="$?"             # This needs to be first
        PS1="$CONEMU_PS1"

        local Clear='\[\e[0m\]'

        local Red='\[\e[2;31m\]'
        local Gre='\[\e[2;32m\]'
        local BGre='\[\e[1;32m\]'
        local BYel='\[\e[1;33m\]'
        local BBlu='\[\e[1;34m\]'
        local Pur='\[\e[2;35m\]'
        local Cya='\[\e[2;35m\]'

        PS1+="${BYel}[${BYel}\W]${Cya}${Clear}"

        # __git_ps1 is slow and I don't think it is that valuable
        PS1+="${BGre}$(__parse_git_root)${Gre}$(__parse_git_branch)${Clear}"

        if [ $EXIT != 0 ]; then
            PS1+=" ${Red}${EXIT}${Clear}"
        fi
        
        if [ -n "$SQ_TOOLCHAIN_FOLDER" ]; then
            PS1+=" ${BBlu}sq:${project}${Clear}"
        fi

        PS1+=" ${Pur}\$${Clear} "
    }

    if [[ $PROMPT_COMMAND != *"__fancy_seeq_prompt_command"* ]]; then
        PROMPT_COMMAND="__fancy_seeq_prompt_command;$PROMPT_COMMAND"
    fi
}

# Run a command in a loop while it succeeds
function tilfail {
    if [ -z ${@+x} ] # is there not a first argument?
    then
        echo "Usage: tilfail <any-command with args>"
        return 1
    fi

    run=1
    while $@
    do 
        echo "*****************************************************************"
        echo "*                                                               *"
        echo "* Run $run - SUCCESSFUL"
        echo "*                                                               *"
        echo "*****************************************************************"
        ((run++))
    done
    echo "*****************************************************************"
    echo "*                                                               *"
    echo "* Run $run - FAILURE"
    echo "*                                                               *"
    echo "*****************************************************************"
}

#
# sq helpers
# Enable by placing `enable_sq_helpers` in bashrc
#
function enable_sq_helpers {
    # Short cut for running a command in the seeq environment. Ex: "e grunt server" to 
    # call ". environment" then "grunt server" in a subshell or just "e" to run 
    # ". environment". If `./sq install" hasn't been run it is run!
    function e {
        if [ ! -z "${SQ_TOOLCHAIN_FOLDER}" ] # has . environment been run?
        then
            echo "*****************************************************************"
            echo "*                                                               *"
            echo "*  Doing nothing since it appears environment has already be    *"
            echo "*  sourced! Try opening a new terminal instead                  *"
            echo "*                                                               *"
            echo "*****************************************************************"
            return 1
        fi

        if [ ! -f ./environment ] # does the environment file not exist?
        then
            # create the environment file
            (./sq install) || return 1;
        fi

        if [ -z ${@+x} ] # is there not a first argument?
        then
            # Run a new bash so that you can `exit` out - bash --rcfile <(echo '. ~/.bashrc; . environment') doesn't work
            echo ". ~/.bashrc; . environment; rm -rf .tmp.bashrc" > .tmp.bashrc && bash --rcfile .tmp.bashrc
        else 
            # Run the command in a shell so that it doesn't polute
            (. environment && "$@")
        fi
    }

    # Ex: "sqe run --clean"
    function sqe {
        e sq "$@"
    }

    # Like `sqe` but allways do sq install fresh
    function sqi {
        ./sq install && 
        sqe "$@"
    }

    # Like `sqe` but rebuild the whole project
    function sqb {
        sqi build -f &&
        sqe image -n &&
        sqe "$@"
    }

    # Like "sq refresh" but with "clean -f". you can pass a sq command to run after. 
    # Ex: "sqcb ide" or "sqcb run --clean"
    function sqcb {
        sqe clean &&
        sqi build -f &&
        sqe image -n &&
        sqe "$@"
    }

    # Pushes up manual test results, makes sure that the tests build before pushing
    function sqsynctests {
        git pull --rebase && (cd behavior/ && sqe build -f) && git push
    }
}