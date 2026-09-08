# ==============================================================================
#
#   THEFLIP
#   "What the fk is this, and how the fk do I run it?"
#
#   Deterministic project archaeology for inherited, unfamiliar,
#   and questionably documented codebases.
#
#   No LLMs. No embeddings. No guessing. No touching shit.
#   Just source code, configuration, structure, and evidence.
#
# ------------------------------------------------------------------------------
#
#   COMMANDS
#
#     tfcs      C# / .NET archaeology
#               projects, dependencies, EF, DI, APIs, config, migrations
#
#     tfjs      JavaScript / TypeScript archaeology
#               packages, frameworks, APIs, data, scripts, config
#
#     tfx       XML / MSBuild archaeology
#               csproj, props, targets, config, schemas, references
#
#     tfhow     Startup archaeology
#               "How TF do I actually run this?"
#               startup projects, blockers, infrastructure, config,
#               databases, migrations, secrets, ports, startup order
#
#     tfcheck   Check TheFlip's external tool dependencies
#
#     tfinstall Install missing TheFlip dependencies
#
# ------------------------------------------------------------------------------
#
#   PHILOSOPHY
#
#     TheFlip is an investigation tool, not an automation framework.
#
#     FACT
#       "17 EF migrations exist."
#
#     FACT
#       "Database.Migrate() was not found."
#
#     INFERENCE
#       "The database schema appears to be prepared externally."
#
#     NOT ASSUMED
#       "Run dotnet ef database update."
#
#     Normal commands summarize and explain.
#     `why` shows the evidence behind a conclusion.
#     `raw` gives you the firehose when you actually want it.
#
# ------------------------------------------------------------------------------
#
#   SAFETY
#
#     READ-ONLY BY DEFAULT.
#
#     TheFlip may inspect files, Git metadata, project metadata, and installed
#     tooling. Analysis commands should not:
#
#       - modify source files
#       - modify configuration
#       - apply or create migrations
#       - start applications
#       - start or stop containers
#       - mutate databases
#       - read secret values
#       - install packages
#
#     tfinstall is the explicit exception: its entire purpose is installation.
#
# ------------------------------------------------------------------------------
#
#   BASIC USAGE
#
#     cd inherited-disaster
#
#     tfcs
#     tfjs
#     tfx
#     tfhow
#
#     tfhow startup
#     tfhow blockers
#     tfhow project Some.Api
#     tfhow project Some.Api order
#
#     tfcs why ApplicationDbContext
#     tfhow why MainDatabase
#
# ------------------------------------------------------------------------------
#
#   RULE #1
#
#     If the repository doesn't prove it, TheFlip shouldn't pretend it knows it.
#
# ==============================================================================

tfcheck() {
    local tools=(
        rg
        fd
        jq
        git
        tokei
        xmlstarlet
        yq
        dotnet
        roslynator
        csharpier
        node
        npm
        pnpm
        yarn
        bun
        column
    )

    local found=0
    local missing=0

    printf '\n\033[1;96m'
    printf '━%.0s' {1..72}
    printf '\n  THEFLIP TOOL CHECK\n'
    printf '━%.0s' {1..72}
    printf '\033[0m\n\n'

    for cmd in "${tools[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf '  \033[92m✓\033[0m \033[1m%-14s\033[0m \033[2m%s\033[0m\n' \
                "$cmd" "$(command -v "$cmd")"
            (( found++ ))
        else
            printf '  \033[91m✗\033[0m \033[1m%-14s\033[0m \033[91mMISSING\033[0m\n' \
                "$cmd"
            (( missing++ ))
        fi
    done

    printf '\n\033[1;96m────────────────────────────────────────────────────────────────────────\033[0m\n'

    if (( missing == 0 )); then
        printf '  \033[92m✓ All %d tools available\033[0m\n\n' "$found"
    else
        printf '  \033[92m%d available\033[0m  \033[91m%d missing\033[0m\n\n' \
            "$found" "$missing"
    fi
}
tfinstall() {
    printf '\n\033[1;96m'
    printf '━%.0s' {1..72}
    printf '\n  THEFLIP TOOL INSTALLER\n'
    printf '━%.0s' {1..72}
    printf '\033[0m\n\n'

    # ------------------------------------------------------------------------
    # Fedora / Ultramarine packages
    # command:package
    # ------------------------------------------------------------------------

    local system_tools=(
        "rg:ripgrep"
        "fd:fd-find"
        "jq:jq"
        "git:git"
        "tokei:tokei"
        "xmlstarlet:xmlstarlet"
        "yq:yq"
        "dotnet:dotnet-sdk-10.0"
        "node:nodejs"
        "npm:npm"
        "column:util-linux"
    )

    local packages=()
    local entry cmd package

    printf '\033[1;96m◆ System tools\033[0m\n'

    for entry in "${system_tools[@]}"; do
        cmd="${entry%%:*}"
        package="${entry#*:}"

        if command -v "$cmd" >/dev/null 2>&1; then
            printf '  \033[92m✓\033[0m %-14s already installed\n' "$cmd"
        else
            printf '  \033[93m+\033[0m %-14s %s\n' "$cmd" "$package"
            packages+=("$package")
        fi
    done

    if (( ${#packages[@]} > 0 )); then
        printf '\n  Installing missing system packages...\n\n'

        if ! sudo dnf install -y "${packages[@]}"; then
            printf '\n  \033[91m✗ dnf installation failed\033[0m\n'
        fi
    else
        printf '\n  \033[92m✓ No system packages needed\033[0m\n'
    fi


    # ------------------------------------------------------------------------
    # .NET global tools
    # ------------------------------------------------------------------------

    printf '\n\033[1;96m◆ .NET tools\033[0m\n'

    export PATH="$PATH:$HOME/.dotnet/tools"

    if command -v dotnet >/dev/null 2>&1; then

        if command -v roslynator >/dev/null 2>&1; then
            printf '  \033[92m✓\033[0m %-14s already installed\n' "roslynator"
        else
            printf '  \033[93m+\033[0m Installing Roslynator\n'
            dotnet tool install --global roslynator.dotnet.cli
        fi

        if command -v csharpier >/dev/null 2>&1; then
            printf '  \033[92m✓\033[0m %-14s already installed\n' "csharpier"
        else
            printf '  \033[93m+\033[0m Installing CSharpier\n'
            dotnet tool install --global csharpier
        fi

    else
        printf '  \033[91m✗ dotnet unavailable; skipping .NET tools\033[0m\n'
    fi


    # ------------------------------------------------------------------------
    # JS package managers
    # ------------------------------------------------------------------------

    printf '\n\033[1;96m◆ JavaScript tooling\033[0m\n'

    if command -v node >/dev/null 2>&1; then

        # pnpm
        if command -v pnpm >/dev/null 2>&1; then
            printf '  \033[92m✓\033[0m %-14s already installed\n' "pnpm"
        elif command -v corepack >/dev/null 2>&1; then
            printf '  \033[93m+\033[0m Enabling pnpm via Corepack\n'
            corepack enable
            corepack prepare pnpm@latest --activate
        elif command -v npm >/dev/null 2>&1; then
            printf '  \033[93m+\033[0m Installing pnpm via npm\n'
            npm install -g pnpm
        fi

        # yarn
        if command -v yarn >/dev/null 2>&1; then
            printf '  \033[92m✓\033[0m %-14s already installed\n' "yarn"
        elif command -v corepack >/dev/null 2>&1; then
            printf '  \033[93m+\033[0m Enabling yarn via Corepack\n'
            corepack enable
            corepack prepare yarn@stable --activate
        elif command -v npm >/dev/null 2>&1; then
            printf '  \033[93m+\033[0m Installing yarn via npm\n'
            npm install -g yarn
        fi

    else
        printf '  \033[91m✗ node unavailable; skipping JS package managers\033[0m\n'
    fi


    # ------------------------------------------------------------------------
    # Bun
    # ------------------------------------------------------------------------

    printf '\n\033[1;96m◆ Optional runtimes\033[0m\n'

    if command -v bun >/dev/null 2>&1; then
        printf '  \033[92m✓\033[0m %-14s already installed\n' "bun"
    elif command -v curl >/dev/null 2>&1; then
        printf '  \033[93m+\033[0m Installing Bun\n'
        curl -fsSL https://bun.sh/install | bash
    else
        printf '  \033[91m✗ curl missing; cannot install Bun\033[0m\n'
    fi


    # ------------------------------------------------------------------------
    # fd compatibility
    # ------------------------------------------------------------------------

    if ! command -v fd >/dev/null 2>&1 &&
       command -v fdfind >/dev/null 2>&1; then

        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"

        printf '\n  \033[92m✓\033[0m Created fd → fdfind compatibility shim\n'
    fi


    # ------------------------------------------------------------------------
    # Finish
    # ------------------------------------------------------------------------

    export PATH="$HOME/.local/bin:$HOME/.dotnet/tools:$HOME/.bun/bin:$PATH"

    printf '\n\033[1;96m────────────────────────────────────────────────────────────────────────\033[0m\n'
    printf '  \033[92mInstallation pass complete.\033[0m\n'
    printf '  Run \033[1;96mtfcheck\033[0m to verify everything.\n\n'
}
# ============================================================================
# COLOR / OUTPUT
# ============================================================================

_tf_init_colors() {
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        TF_RESET=$'\033[0m'; TF_BOLD=$'\033[1m'; TF_DIM=$'\033[2m'
        TF_RED=$'\033[31m'; TF_GREEN=$'\033[32m'; TF_YELLOW=$'\033[33m'
        TF_BLUE=$'\033[34m'; TF_MAGENTA=$'\033[35m'; TF_CYAN=$'\033[36m'
        TF_WHITE=$'\033[37m'; TF_BRED=$'\033[91m'; TF_BGREEN=$'\033[92m'
        TF_BYELLOW=$'\033[93m'; TF_BBLUE=$'\033[94m'
        TF_BMAGENTA=$'\033[95m'; TF_BCYAN=$'\033[96m'
    else
        TF_RESET=""; TF_BOLD=""; TF_DIM=""; TF_RED=""; TF_GREEN=""
        TF_YELLOW=""; TF_BLUE=""; TF_MAGENTA=""; TF_CYAN=""; TF_WHITE=""
        TF_BRED=""; TF_BGREEN=""; TF_BYELLOW=""; TF_BBLUE=""
        TF_BMAGENTA=""; TF_BCYAN=""
    fi
}
_tf_init_colors

_tf_title() {
    printf '\n%s%s' "$TF_BOLD" "$TF_BCYAN"
    printf '━%.0s' {1..72}
    printf '\n  %s\n' "$1"
    printf '━%.0s' {1..72}
    printf '%s\n' "$TF_RESET"
}
_tf_section() { printf '\n%s%s◆ %s%s\n' "$TF_BOLD" "$TF_CYAN" "$1" "$TF_RESET"; }
_tf_ok()      { printf '  %s✓%s %-20s %s%s%s\n' "$TF_BGREEN" "$TF_RESET" "$1" "$TF_BGREEN" "$2" "$TF_RESET"; }
_tf_warn()    { printf '  %s!%s %-20s %s%s%s\n' "$TF_BYELLOW" "$TF_RESET" "$1" "$TF_BYELLOW" "$2" "$TF_RESET"; }
_tf_bad()     { printf '  %s✗%s %-20s %s%s%s\n' "$TF_BRED" "$TF_RESET" "$1" "$TF_BRED" "$2" "$TF_RESET"; }
_tf_item()    { printf '  %s│%s %-20s %s%s%s\n' "$TF_DIM" "$TF_RESET" "$1" "$TF_BCYAN" "$2" "$TF_RESET"; }
_tf_label()   { printf '      %s%s%-18s%s ' "$TF_BOLD" "$TF_WHITE" "$1" "$TF_RESET"; }
_tf_value()   { printf '%s%s%s%s\n' "$TF_BOLD" "$TF_BCYAN" "$1" "$TF_RESET"; }
_tf_pathval() { printf '%s%s%s%s\n' "$TF_BOLD" "$TF_BBLUE" "$1" "$TF_RESET"; }
_tf_cfgval()  { printf '%s%s%s%s\n' "$TF_BOLD" "$TF_BYELLOW" "$1" "$TF_RESET"; }
_tf_dbval()   { printf '%s%s%s%s\n' "$TF_BOLD" "$TF_BMAGENTA" "$1" "$TF_RESET"; }
_tf_dim()     { printf '  %s%s%s\n' "$TF_DIM" "$1" "$TF_RESET"; }
_tf_found()   { printf '  %s●%s %s%s%s\n' "$TF_BGREEN" "$TF_RESET" "$TF_BGREEN" "$1" "$TF_RESET"; }
_tf_tech()    { printf '  %s◆%s %s%s%s\n' "$TF_BMAGENTA" "$TF_RESET" "$TF_BMAGENTA" "$1" "$TF_RESET"; }
_tf_database(){ printf '  %sDB%s  %s%s%s\n' "$TF_BMAGENTA" "$TF_RESET" "$TF_BMAGENTA" "$1" "$TF_RESET"; }
_tf_framework(){ printf '  %sFW%s  %s%s%s\n' "$TF_BGREEN" "$TF_RESET" "$TF_BGREEN" "$1" "$TF_RESET"; }
_tf_messaging(){ printf '  %sMQ%s  %s%s%s\n' "$TF_BYELLOW" "$TF_RESET" "$TF_BYELLOW" "$1" "$TF_RESET"; }
_tf_testtech(){ printf '  %sTST%s %s%s%s\n' "$TF_BBLUE" "$TF_RESET" "$TF_BBLUE" "$1" "$TF_RESET"; }
_tf_security(){ printf '  %sSEC%s %s%s%s\n' "$TF_BRED" "$TF_RESET" "$TF_BRED" "$1" "$TF_RESET"; }

_tf_need() {
    command -v "$1" >/dev/null 2>&1 || { _tf_bad "missing tool" "$1"; return 1; }
}
_tf_count_files() {
    local pattern="$1"; shift
    rg -l "$pattern" "$@" . 2>/dev/null | wc -l | tr -d ' '
}
_tf_count_matches() {
    local pattern="$1"; shift
    rg "$pattern" "$@" . 2>/dev/null | wc -l | tr -d ' '
}
_tf_git() {
    if command -v git >/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _tf_label "git branch"; _tf_value "$(git branch --show-current)"
        local dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
        (( dirty == 0 )) && _tf_ok "working tree" "clean" || _tf_warn "working tree" "$dirty changed/untracked"
    fi
}
_tf_tool_status() {
    local cmd="$1" label="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        _tf_ok "$label" "available"
    else
        _tf_warn "$label" "not installed"
    fi
}

# ============================================================================
# C# / .NET
# ============================================================================

tfcs() {
    local cmd="${1:-summary}"
    [[ $# -gt 0 ]] && shift
    _tf_need rg || return
    _tf_need fd || return

    case "$cmd" in
    summary|overview|ov)
        _tf_title "C# / .NET PROJECT AUTOPSY"
        _tf_section "Project"
        _tf_item "C# files" "$(fd -e cs --exclude bin --exclude obj | wc -l | tr -d ' ')"
        _tf_item "projects" "$(fd -e csproj --exclude bin --exclude obj | wc -l | tr -d ' ')"
        _tf_item "test projects" "$(fd -e csproj | rg -i 'test' | wc -l | tr -d ' ')"
        _tf_item "solutions" "$(fd -e sln -e slnx -e slnf | wc -l | tr -d ' ')"
        command -v dotnet >/dev/null && _tf_ok ".NET SDK" "$(dotnet --version 2>/dev/null)" || _tf_warn ".NET SDK" "not available"
        _tf_git

        _tf_section "Architecture"
        rg -q 'Aspire\.Hosting|DistributedApplication' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_framework ".NET Aspire"
        rg -q 'Microsoft\.AspNetCore|WebApplication\.CreateBuilder' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_framework "ASP.NET Core"
        rg -q 'Microsoft\.Maui' -g '*.csproj' . 2>/dev/null && _tf_framework ".NET MAUI"
        rg -q 'Grpc\.AspNetCore|AddGrpc|MapGrpcService' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_framework "gRPC"
        rg -q 'MediatR' -g '*.cs' -g '*.csproj' -g 'Directory.Packages.props' . 2>/dev/null && _tf_tech "MediatR"
        rg -q 'OpenTelemetry' -g '*.cs' -g '*.csproj' -g 'Directory.Packages.props' . 2>/dev/null && _tf_tech "OpenTelemetry"

        _tf_section "Data"
        _tf_item "DbContext files" "$(_tf_count_files ':[[:space:]]*[^,{]*DbContext|DbContextOptions<' -g '*.cs')"
        _tf_item "DbSet declarations" "$(_tf_count_matches 'DbSet[[:space:]]*<' -g '*.cs')"
        _tf_item "migration files" "$(_tf_count_files ': *Migration|MigrationBuilder' -g '*.cs')"
        rg -q 'Npgsql|UseNpgsql|Aspire\.Npgsql' -g '*.cs' -g '*.csproj' -g 'Directory.Packages.props' . 2>/dev/null && _tf_database "PostgreSQL"
        rg -q 'SqlServer|UseSqlServer|Microsoft\.Data\.SqlClient' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_database "SQL Server"
        rg -q 'UseSqlite|Microsoft\.Data\.Sqlite' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_database "SQLite"
        rg -q 'StackExchange\.Redis|Aspire\.StackExchange\.Redis' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_database "Redis"
        rg -q 'MongoDB|MongoClient' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_database "MongoDB"
        rg -q 'Dapper' -g '*.cs' -g '*.csproj' -g 'Directory.Packages.props' . 2>/dev/null && _tf_tech "Dapper"

        _tf_section "Messaging / External Systems"
        rg -q 'RabbitMQ|Aspire\.RabbitMQ' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_messaging "RabbitMQ"
        rg -q 'Kafka|Confluent\.Kafka' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_messaging "Kafka"
        rg -q 'Azure\.ServiceBus|ServiceBusClient' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_messaging "Azure Service Bus"
        rg -q 'OpenAI|Ollama|SemanticKernel|Microsoft\.Extensions\.AI' -g '*.cs' -g '*.csproj' . 2>/dev/null && _tf_tech "AI/LLM integration"

        _tf_section "Tooling"
        _tf_tool_status tokei "tokei"
        _tf_tool_status roslynator "Roslynator"
        _tf_tool_status csharpier "CSharpier"
        command -v dotnet >/dev/null && _tf_ok "dotnet analyzers" "available via SDK"

        _tf_section "Next"
        printf '  %s%-18s%s %s\n' "$TF_BGREEN" "tfcs map" "$TF_RESET" "project relationships"
        printf '  %s%-18s%s %s\n' "$TF_BMAGENTA" "tfcs db" "$TF_RESET" "DbContext/database/config map"
        printf '  %s%-18s%s %s\n' "$TF_BYELLOW" "tfcs config" "$TF_RESET" "configuration provenance"
        printf '  %s%-18s%s %s\n' "$TF_BBLUE" "tfcs analyze" "$TF_RESET" "read-only analyzer checks"
        printf '  %s%-18s%s %s\n' "$TF_BCYAN" "tfcs why NAME" "$TF_RESET" "show evidence"
        ;;

    map)
        _tf_title ".NET PROJECT MAP"
        while IFS= read -r proj; do
            (
                local name="$(basename "$proj" .csproj)"
                printf '\n  %s%s%s%s\n' "$TF_BOLD" "$TF_BGREEN" "$name" "$TF_RESET"
                _tf_label "path"; _tf_pathval "$proj"

                local refs="$(rg -o 'ProjectReference[[:space:]]+Include="[^"]+"' "$proj" 2>/dev/null |
                    sed 's/.*Include="//;s/"$//' | sed 's#\\#/#g' | xargs -r -n1 basename | sed 's/\.csproj$//')"
                if [[ -n "$refs" ]]; then
                    _tf_label "depends on"; printf '\n'
                    while IFS= read -r ref; do printf '        %s├─%s %s%s%s\n' "$TF_DIM" "$TF_RESET" "$TF_BBLUE" "$ref" "$TF_RESET"; done <<< "$refs"
                fi

                local content="$(cat "$proj" 2>/dev/null)"
                [[ "$content" == *"Aspire.Hosting"* ]] && { _tf_label "role"; _tf_value "Aspire orchestrator"; }
                [[ "$content" == *"Microsoft.NET.Sdk.Web"* ]] && { _tf_label "role"; _tf_value "Web/API"; }
                [[ "$content" == *"EntityFrameworkCore"* ]] && { _tf_label "data"; _tf_dbval "Entity Framework Core"; }
                [[ "$content" == *"Npgsql"* ]] && { _tf_label "database"; _tf_dbval "PostgreSQL"; }
                [[ "$content" == *"SqlServer"* ]] && { _tf_label "database"; _tf_dbval "SQL Server"; }
                [[ "$content" == *"Redis"* ]] && { _tf_label "storage"; _tf_dbval "Redis"; }
                [[ "$content" == *"RabbitMQ"* ]] && { _tf_label "messaging"; _tf_cfgval "RabbitMQ"; }
                [[ "$content" == *"Grpc"* ]] && { _tf_label "protocol"; _tf_value "gRPC"; }
                [[ "$content" == *"Maui"* ]] && { _tf_label "UI"; _tf_value ".NET MAUI"; }
            )
        done < <(fd -e csproj --exclude bin --exclude obj | sort)
        ;;

    # ========================================================================
    # SMART DATABASE / EF MAP
    # ========================================================================

    db)
        _tf_title "DATABASE / EF MAP"

        # --------------------------------------------------------------------
        # ACTUAL DBCONTEXT DISCOVERY
        #
        # Discovery is intentionally broad, then validated.
        #
        # Accept:
        #   class CatalogContext : DbContext
        #   class OrderingContext : DbContext, IUnitOfWork
        #   class WebhooksContext(...) : DbContext(options)
        #   class ApplicationDbContext(...) : IdentityDbContext<...>
        #
        # Reject:
        #   class UsersSeed(...) : IDbSeeder<ApplicationDbContext>
        # --------------------------------------------------------------------

        _tf_section "DbContexts"

        local context_lines=""

        context_lines="$(
            rg -n \
                '^[[:space:]]*(public|internal|protected|private)?[[:space:]]*(sealed[[:space:]]+|abstract[[:space:]]+|partial[[:space:]]+)*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*.*:[[:space:]].*(DbContext|IdentityDbContext)' \
                -g '*.cs' \
                --glob '!**/bin/**' \
                --glob '!**/obj/**' \
                . 2>/dev/null |
            while IFS= read -r candidate; do

                local declaration=""
                declaration="${candidate#*:*:}"

                # Actual inheritance must begin with a DbContext-like base
                # after the colon. This prevents:
                #
                #   : IDbSeeder<ApplicationDbContext>
                #
                # from being interpreted as a context.

                if printf '%s\n' "$declaration" |
                    rg -q \
                    ':[[:space:]]*([A-Za-z_][A-Za-z0-9_.]*\.)?(IdentityDbContext|DbContext|[A-Za-z_][A-Za-z0-9_]*DbContext)(<[^>]+>)?([[:space:](,]|$)'
                then
                    printf '%s\n' "$candidate"
                fi
            done
        )"


        if [[ -z "$context_lines" ]]; then
            _tf_warn "DbContexts" "none detected by static scan"
        else

            while IFS= read -r line; do
                [[ -z "$line" ]] && continue

                # Every context gets its own subshell.
                #
                # This is important in zsh: it prevents values such as
                # configkey/registration/file from leaking from one context
                # into the next one.

                (
                    local file=""
                    local rest=""
                    local lineno=""
                    local text=""
                    local ctx=""
                    local project=""
                    local project_dir=""

                    local registration=""
                    local regfile=""
                    local regline=""
                    local regtext=""

                    local configkey=""
                    local provider=""
                    local provider_confidence=""

                    local entitycount=0
                    local configcount=0
                    local migrationcount=0

                    local has_model_creating=0
                    local has_apply_configs=0


                    # --------------------------------------------------------
                    # PARSE RG RESULT
                    # --------------------------------------------------------

                    file="${line%%:*}"

                    rest="${line#*:}"
                    lineno="${rest%%:*}"

                    text="${rest#*:}"

                    ctx="$(
                        printf '%s\n' "$text" |
                        sed -nE \
                            's/.*class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p'
                    )"

                    [[ -z "$ctx" ]] && exit 0


                    # --------------------------------------------------------
                    # FIND OWNING PROJECT
                    #
                    # Walk upward from the context until we find the nearest
                    # .csproj. This is much safer than searching the whole
                    # repository and assuming the first project is the owner.
                    # --------------------------------------------------------

                    local walkdir=""
                    walkdir="$(dirname "$file")"

                    while [[ "$walkdir" != "." && "$walkdir" != "/" ]]; do

                        project="$(
                            fd \
                                --max-depth 1 \
                                -e csproj \
                                . \
                                "$walkdir" \
                                2>/dev/null |
                            head -1
                        )"

                        [[ -n "$project" ]] && break

                        walkdir="$(dirname "$walkdir")"
                    done

                    if [[ -n "$project" ]]; then
                        project_dir="$(dirname "$project")"
                    else
                        project_dir="$(dirname "$file")"
                    fi


                    # --------------------------------------------------------
                    # HEADER
                    # --------------------------------------------------------

                    printf '\n  %s%s%s%s\n' \
                        "$TF_BOLD" \
                        "$TF_BMAGENTA" \
                        "$ctx" \
                        "$TF_RESET"


                    _tf_label "defined"
                    _tf_pathval "$file:$lineno"


                    if [[ -n "$project" ]]; then
                        _tf_label "project"
                        _tf_pathval "$(basename "$project" .csproj)"
                    fi


                    # --------------------------------------------------------
                    # REGISTRATION
                    #
                    # Search for registrations referring to THIS context.
                    # --------------------------------------------------------

                    registration="$(
                        rg -n \
                            "AddDbContext[^(<]*<${ctx}>|AddDbContextPool[^(<]*<${ctx}>|AddDbContextFactory[^(<]*<${ctx}>|AddPooledDbContextFactory[^(<]*<${ctx}>|AddNpgsqlDbContext<${ctx}>|AddSqlServerDbContext<${ctx}>|AddSqliteDbContext<${ctx}>" \
                            -g '*.cs' \
                            --glob '!**/bin/**' \
                            --glob '!**/obj/**' \
                            . 2>/dev/null |
                        head -1
                    )"


                    if [[ -n "$registration" ]]; then

                        regfile="${registration%%:*}"

                        rest="${registration#*:}"
                        regline="${rest%%:*}"

                        regtext="${rest#*:}"


                        _tf_label "registration"
                        _tf_pathval "$regfile:$regline"


                        # Source code goes underneath instead of wrecking
                        # the column alignment.

                        printf '      %-19s%s%s%s\n' \
                            "" \
                            "$TF_DIM" \
                            "$(printf '%s' "$regtext" |
                               sed 's/^[[:space:]]*//')" \
                            "$TF_RESET"

                    else

                        _tf_label "registration"

                        printf '%snot found%s\n' \
                            "$TF_BYELLOW" \
                            "$TF_RESET"

                    fi


                    # --------------------------------------------------------
                    # CONFIGURATION KEY
                    #
                    # Confidence order:
                    #
                    # 1. Exact Aspire registration:
                    #      AddNpgsqlDbContext<Foo>("foodb")
                    #
                    # 2. GetConnectionString() near the exact registration.
                    #
                    # Do NOT search arbitrary files for the first quoted
                    # string. That caused things like textEmbeddingModel to
                    # become fake DB config keys.
                    # --------------------------------------------------------

                    configkey="$(
                        rg \
                            "Add(Npgsql|SqlServer|Sqlite)DbContext<${ctx}>[[:space:]]*\\([[:space:]]*\"[^\"]+\"" \
                            -g '*.cs' \
                            --glob '!**/bin/**' \
                            --glob '!**/obj/**' \
                            . 2>/dev/null |
                        head -1 |
                        grep -oE '"[^"]+"' |
                        head -1 |
                        tr -d '"'
                    )"


                    # Look around the actual registration line for:
                    #
                    # GetConnectionString("orderingdb")
                    #
                    # We inspect a limited window instead of the whole file.

                    if [[ -z "$configkey" &&
                          -n "$regfile" &&
                          -n "$regline" ]]
                    then

                        configkey="$(
                            awk \
                                -v start="$regline" \
                                -v end="$((regline + 15))" \
                                '
                                NR >= start && NR <= end {
                                    print
                                }
                                ' \
                                "$regfile" \
                                2>/dev/null |
                            grep -oE \
                                'GetConnectionString\("[^"]+"\)' |
                            head -1 |
                            grep -oE '"[^"]+"' |
                            tr -d '"'
                        )"

                    fi


                    _tf_label "config key"

                    if [[ -n "$configkey" ]]; then
                        _tf_cfgval "$configkey"
                    else
                        printf '%sunknown%s\n' \
                            "$TF_DIM" \
                            "$TF_RESET"
                    fi


                    # --------------------------------------------------------
                    # EXPLICIT DBSETS
                    #
                    # This deliberately says "explicit DbSets".
                    #
                    # DbSet count != entity count.
                    #
                    # EF entities can also come from model configuration,
                    # Identity, IEntityTypeConfiguration<T>, etc.
                    # --------------------------------------------------------

                    entitycount="$(
                        rg \
                            'DbSet[[:space:]]*<' \
                            "$file" \
                            2>/dev/null |
                        wc -l |
                        tr -d ' '
                    )"


                    _tf_label "explicit DbSets"
                    _tf_value "$entitycount"


                    # --------------------------------------------------------
                    # ENTITY TYPE CONFIGURATIONS
                    #
                    # Search the owning project, not merely the directory
                    # containing the context.
                    # --------------------------------------------------------

                    configcount="$(
                        rg -o \
                            'IEntityTypeConfiguration[[:space:]]*<[A-Za-z_][A-Za-z0-9_.]*>' \
                            -g '*.cs' \
                            --glob '!**/bin/**' \
                            --glob '!**/obj/**' \
                            "$project_dir" \
                            2>/dev/null |
                        sort -u |
                        wc -l |
                        tr -d ' '
                    )"


                    if (( configcount > 0 )); then
                        _tf_label "entity configs"
                        _tf_value "$configcount"
                    fi


                    # --------------------------------------------------------
                    # MODEL CONFIGURATION STYLE
                    # --------------------------------------------------------

                    if rg -q \
                        'OnModelCreating[[:space:]]*\(' \
                        "$file" \
                        2>/dev/null
                    then
                        has_model_creating=1
                    fi


                    if rg -q \
                        'ApplyConfigurationsFromAssembly|ApplyConfiguration[[:space:]]*\(' \
                        -g '*.cs' \
                        "$project_dir" \
                        2>/dev/null
                    then
                        has_apply_configs=1
                    fi


                    if (( has_model_creating == 1 )); then
                        _tf_label "model config"
                        _tf_value "OnModelCreating"
                    fi


                    if (( has_apply_configs == 1 )); then
                        _tf_label "config loading"
                        _tf_value "IEntityTypeConfiguration"
                    fi


                    # --------------------------------------------------------
                    # PROVIDER DETECTION
                    #
                    # Evidence priority:
                    #
                    # HIGH:
                    #   exact registration references provider
                    #
                    # MEDIUM:
                    #   registration file calls UseNpgsql/etc.
                    #
                    # LOW:
                    #   owning project references provider package
                    #
                    # Low-confidence inference is explicitly labelled.
                    # --------------------------------------------------------

                    if [[ "$registration" == *"Npgsql"* ]]; then

                        provider="PostgreSQL"
                        provider_confidence="direct"

                    elif [[ "$registration" == *"SqlServer"* ]]; then

                        provider="SQL Server"
                        provider_confidence="direct"

                    elif [[ "$registration" == *"Sqlite"* ]]; then

                        provider="SQLite"
                        provider_confidence="direct"


                    elif [[ -n "$regfile" ]] &&
                         rg -q \
                            'UseNpgsql' \
                            "$regfile" \
                            2>/dev/null
                    then

                        provider="PostgreSQL"
                        provider_confidence="registration file"


                    elif [[ -n "$regfile" ]] &&
                         rg -q \
                            'UseSqlServer' \
                            "$regfile" \
                            2>/dev/null
                    then

                        provider="SQL Server"
                        provider_confidence="registration file"


                    elif [[ -n "$regfile" ]] &&
                         rg -q \
                            'UseSqlite' \
                            "$regfile" \
                            2>/dev/null
                    then

                        provider="SQLite"
                        provider_confidence="registration file"


                    elif [[ -n "$project" ]] &&
                         rg -q \
                            'Npgsql|Aspire\.Npgsql' \
                            "$project" \
                            2>/dev/null
                    then

                        provider="PostgreSQL"
                        provider_confidence="project package"


                    elif [[ -n "$project" ]] &&
                         rg -q \
                            'SqlServer' \
                            "$project" \
                            2>/dev/null
                    then

                        provider="SQL Server"
                        provider_confidence="project package"


                    elif [[ -n "$project" ]] &&
                         rg -q \
                            'Sqlite' \
                            "$project" \
                            2>/dev/null
                    then

                        provider="SQLite"
                        provider_confidence="project package"

                    fi


                    _tf_label "provider"

                    if [[ -n "$provider" ]]; then

                        if [[ "$provider_confidence" == "direct" ]]; then

                            _tf_dbval "$provider"

                        else

                            printf '%s%s%s%s %s(%s)%s\n' \
                                "$TF_BOLD" \
                                "$TF_BMAGENTA" \
                                "$provider" \
                                "$TF_RESET" \
                                "$TF_DIM" \
                                "$provider_confidence" \
                                "$TF_RESET"

                        fi

                    else

                        printf '%sunknown%s\n' \
                            "$TF_DIM" \
                            "$TF_RESET"

                    fi


                    # --------------------------------------------------------
                    # MIGRATIONS
                    #
                    # Search the owning project first.
                    #
                    # Snapshot files are particularly useful because EF
                    # normally associates them with a specific context.
                    # --------------------------------------------------------

                    migrationcount="$(
                        {
                            rg -l \
                                "DbContext\\(typeof\\(${ctx}\\)\\)|${ctx}ModelSnapshot" \
                                -g '*.cs' \
                                --glob '**/Migrations/**' \
                                "$project_dir" \
                                2>/dev/null

                            rg -l \
                                "\\[DbContext\\(typeof\\(${ctx}\\)\\)\\]" \
                                -g '*.cs' \
                                "$project_dir" \
                                2>/dev/null
                        } |
                        sort -u |
                        wc -l |
                        tr -d ' '
                    )"


                    if (( migrationcount > 0 )); then
                        _tf_label "migration refs"
                        _tf_value "$migrationcount"
                    fi


                    # --------------------------------------------------------
                    # CONTEXT CONSUMERS
                    #
                    # Useful for unfamiliar projects: where is this context
                    # injected/used outside its declaration and registration?
                    # --------------------------------------------------------

                    local consumers=0

                    consumers="$(
                        rg -l \
                            "\\b${ctx}\\b" \
                            -g '*.cs' \
                            --glob '!**/bin/**' \
                            --glob '!**/obj/**' \
                            . 2>/dev/null |
                        grep -Fvx "$file" |
                        {
                            if [[ -n "$regfile" ]]; then
                                grep -Fvx "$regfile"
                            else
                                cat
                            fi
                        } |
                        wc -l |
                        tr -d ' '
                    )"


                    _tf_label "consumer files"
                    _tf_value "$consumers"


                    # --------------------------------------------------------
                    # CONFIDENCE
                    #
                    # Give a compact indication of how much evidence we
                    # actually found.
                    # --------------------------------------------------------

                    local evidence=0

                    [[ -n "$registration" ]] && (( evidence++ ))
                    [[ -n "$configkey" ]] && (( evidence++ ))
                    [[ -n "$provider" ]] && (( evidence++ ))
                    [[ -n "$project" ]] && (( evidence++ ))


                    _tf_label "confidence"

                    if (( evidence >= 4 )); then

                        printf '%s%sHIGH%s\n' \
                            "$TF_BOLD" \
                            "$TF_BGREEN" \
                            "$TF_RESET"

                    elif (( evidence >= 2 )); then

                        printf '%s%sMEDIUM%s\n' \
                            "$TF_BOLD" \
                            "$TF_BYELLOW" \
                            "$TF_RESET"

                    else

                        printf '%s%sLOW%s\n' \
                            "$TF_BOLD" \
                            "$TF_BRED" \
                            "$TF_RESET"

                    fi

                )

            done <<< "$context_lines"

        fi


        # ====================================================================
        # DATABASE PROVIDERS
        # ====================================================================

        _tf_section "Database Providers"

        local provider_found=0


        if rg -q \
            'Npgsql|UseNpgsql|Aspire\.Npgsql' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "PostgreSQL"
            provider_found=1
        fi


        if rg -q \
            'SqlServer|UseSqlServer|Microsoft\.Data\.SqlClient' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "SQL Server"
            provider_found=1
        fi


        if rg -q \
            'Sqlite|UseSqlite|Microsoft\.Data\.Sqlite' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "SQLite"
            provider_found=1
        fi


        if rg -q \
            'MySql|Pomelo\.EntityFrameworkCore\.MySql' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "MySQL"
            provider_found=1
        fi


        if rg -q \
            'Oracle\.EntityFrameworkCore|OracleConnection' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "Oracle"
            provider_found=1
        fi


        (( provider_found == 0 )) &&
            _tf_dim "No known relational provider detected."


        # ====================================================================
        # OTHER DATA TECHNOLOGIES
        # ====================================================================

        _tf_section "Other Data Technologies"

        local other_found=0


        if rg -q \
            'Dapper' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_tech "Dapper"
            other_found=1
        fi


        if rg -q \
            'StackExchange\.Redis|Aspire\.StackExchange\.Redis|RedisConnection|ConnectionMultiplexer' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "Redis"
            other_found=1
        fi


        if rg -q \
            'MongoDB|MongoClient' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "MongoDB"
            other_found=1
        fi


        if rg -q \
            'Pgvector|pgvector' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_tech "pgvector"
            other_found=1
        fi


        if rg -q \
            'CosmosClient|Microsoft\.Azure\.Cosmos|UseCosmos' \
            -g '*.cs' \
            -g '*.csproj' \
            -g 'Directory.Packages.props' \
            . 2>/dev/null
        then
            _tf_database "Azure Cosmos DB"
            other_found=1
        fi


        (( other_found == 0 )) &&
            _tf_dim "No additional data technologies detected."


        # ====================================================================
        # RAW SQL
        # ====================================================================

        _tf_section "Raw SQL"

        local rawsql_files=0
        local dapper_files=0


        rawsql_files="$(
            rg -l \
                'FromSqlRaw|FromSqlInterpolated|ExecuteSqlRaw|ExecuteSqlInterpolated|SqlCommand|DbCommand|ExecuteReader|ExecuteNonQuery' \
                -g '*.cs' \
                --glob '!**/bin/**' \
                --glob '!**/obj/**' \
                . 2>/dev/null |
            wc -l |
            tr -d ' '
        )"


        dapper_files="$(
            rg -l \
                '\.(Query|QueryAsync|QueryFirst|QueryFirstAsync|QuerySingle|QuerySingleAsync|Execute|ExecuteAsync)[<(]' \
                -g '*.cs' \
                --glob '!**/bin/**' \
                --glob '!**/obj/**' \
                . 2>/dev/null |
            wc -l |
            tr -d ' '
        )"


        _tf_label "EF/raw SQL files"
        _tf_value "$rawsql_files"

        _tf_label "Dapper-like files"
        _tf_value "$dapper_files"


        # ====================================================================
        # DATABASE CONFIGURATION
        # ====================================================================

        _tf_section "Database Configuration"

        local connection_keys=""

        connection_keys="$(
            {
                rg -o \
                    'GetConnectionString\("[^"]+"\)' \
                    -g '*.cs' \
                    . 2>/dev/null |
                grep -oE '"[^"]+"' |
                tr -d '"'

                rg -o \
                    'Add(Npgsql|SqlServer|Sqlite)DbContext<[A-Za-z_][A-Za-z0-9_]*>\("[^"]+"' \
                    -g '*.cs' \
                    . 2>/dev/null |
                grep -oE '"[^"]+"' |
                tr -d '"'
            } |
            sort -u
        )"


        if [[ -n "$connection_keys" ]]; then

            while IFS= read -r key; do
                [[ -z "$key" ]] && continue

                local refs=0

                refs="$(
                    rg -l \
                        "\"${key}\"" \
                        -g '*.cs' \
                        -g '*.json' \
                        -g '*.yaml' \
                        -g '*.yml' \
                        . 2>/dev/null |
                    wc -l |
                    tr -d ' '
                )"

                printf '  %s%-28s%s %s%s%s refs\n' \
                    "$TF_BYELLOW" \
                    "$key" \
                    "$TF_RESET" \
                    "$TF_BCYAN" \
                    "$refs" \
                    "$TF_RESET"

            done <<< "$connection_keys"

        else

            _tf_dim "No explicit connection-string keys detected."

        fi


        # ====================================================================
        # CONFIG FILES CONTAINING CONNECTION STRINGS
        # ====================================================================

        _tf_section "Configuration Files With Database Evidence"

        local config_files=""

        config_files="$(
            rg -l \
                'ConnectionStrings|Host=|Server=|Data Source=|Database=|Initial Catalog=' \
                -g '*.json' \
                -g '*.config' \
                -g '*.yaml' \
                -g '*.yml' \
                -g '*.env*' \
                --hidden \
                --glob '!**/bin/**' \
                --glob '!**/obj/**' \
                . 2>/dev/null
        )"


        if [[ -n "$config_files" ]]; then

            while IFS= read -r cfg; do
                printf '  %s%s%s\n' \
                    "$TF_BBLUE" \
                    "$cfg" \
                    "$TF_RESET"
            done <<< "$config_files"

        else

            _tf_dim "No obvious database configuration files detected."

        fi


        # ====================================================================
        # QUICK COMMAND HINTS
        # ====================================================================

        _tf_section "Drill Down"

        printf '  %s%-22s%s %s\n' \
            "$TF_BCYAN" \
            "tfcs why Context" \
            "$TF_RESET" \
            "show evidence for a DbContext"

        printf '  %s%-22s%s %s\n' \
            "$TF_BCYAN" \
            "tfcs why KEY" \
            "$TF_RESET" \
            "trace a configuration key"

        printf '  %s%-22s%s %s\n' \
            "$TF_BCYAN" \
            "tfcs migrations" \
            "$TF_RESET" \
            "inspect EF migrations"

        printf '  %s%-22s%s %s\n' \
            "$TF_BCYAN" \
            "tfcs raw db" \
            "$TF_RESET" \
            "show the database evidence firehose"

        echo
        ;; 
        
    deps)
        _tf_title ".NET DEPENDENCY SUMMARY"
        _tf_section "Project Relationships"
        while IFS= read -r proj; do
            local count="$(rg '<ProjectReference' "$proj" 2>/dev/null | wc -l | tr -d ' ')"
            (( count == 0 )) && continue
            printf '  %s%-32s%s %s%s%s refs\n' "$TF_BOLD" "$(basename "$proj" .csproj)" "$TF_RESET" "$TF_BCYAN" "$count" "$TF_RESET"
            rg -o 'ProjectReference[[:space:]]+Include="[^"]+"' "$proj" 2>/dev/null |
                sed 's/.*Include="//;s/"$//' | sed 's#\\#/#g' |
                while IFS= read -r ref; do printf '      %s└─%s %s%s%s\n' "$TF_DIM" "$TF_RESET" "$TF_BBLUE" "$(basename "$ref" .csproj)" "$TF_RESET"; done
        done < <(fd -e csproj | sort)

        _tf_section "Technology Signals"
        local s
        for s in \
            'EntityFrameworkCore|Entity Framework Core' 'Npgsql|PostgreSQL' 'SqlServer|SQL Server' \
            'Dapper|Dapper' 'Redis|Redis' 'RabbitMQ|RabbitMQ' 'Grpc|gRPC' 'MediatR|MediatR' \
            'OpenTelemetry|OpenTelemetry' 'FluentValidation|FluentValidation' \
            'IdentityServer|IdentityServer' 'NSubstitute|NSubstitute' 'xunit|xUnit' \
            'Aspire\.Hosting|.NET Aspire' 'Ollama|Ollama' 'Pgvector|pgvector'; do
            local pattern="${s%%|*}" label="${s#*|}"
            local count="$(rg -l "$pattern" -g '*.csproj' -g 'Directory.Packages.props' . 2>/dev/null | wc -l | tr -d ' ')"
            (( count > 0 )) && _tf_item "$label" "$count evidence files"
        done
        ;;

    config|conf)
        _tf_title ".NET CONFIGURATION MAP"
        _tf_section "Configuration Files"
        fd '^(appsettings.*\.json|launchSettings\.json|.*\.config)$' | while IFS= read -r f; do printf '  %s%s%s\n' "$TF_BBLUE" "$f" "$TF_RESET"; done

        _tf_section "Connection String Keys"
        rg -o 'GetConnectionString\("[^"]+"\)' -g '*.cs' . 2>/dev/null |
            sed -E 's/.*GetConnectionString\("([^"]+)"\).*/\1/' | sort -u |
            while IFS= read -r key; do
                local refs="$(rg -l "GetConnectionString\\(\"$key\"\\)" -g '*.cs' . 2>/dev/null | wc -l | tr -d ' ')"
                printf '  %s%-28s%s %s%s%s consumers\n' "$TF_BYELLOW" "$key" "$TF_RESET" "$TF_BCYAN" "$refs" "$TF_RESET"
            done

        _tf_section "Strongly Typed Config"
        rg -o 'IOptions(Monitor|Snapshot)?<[A-Za-z0-9_]+>' -g '*.cs' . 2>/dev/null | sort -u |
            while IFS= read -r x; do printf '  %s%s%s\n' "$TF_BMAGENTA" "$x" "$TF_RESET"; done

        _tf_section "Override Sources"
        rg -q 'AddEnvironmentVariables' -g '*.cs' . 2>/dev/null && _tf_found "Environment variables"
        rg -q 'AddUserSecrets' -g '*.cs' . 2>/dev/null && _tf_found "User Secrets"
        rg -q 'AddCommandLine' -g '*.cs' . 2>/dev/null && _tf_found "Command-line configuration"
        fd 'launchSettings\.json' | grep -q . && _tf_found "launchSettings.json"
        ;;

    services|di)
        _tf_title "DEPENDENCY INJECTION MAP"
        _tf_section "Explicit Registrations"
        rg -n 'AddScoped|AddTransient|AddSingleton|AddKeyedScoped|AddKeyedTransient|AddKeyedSingleton' -g '*.cs' . 2>/dev/null |
            while IFS= read -r x; do printf '  %s%s%s\n' "$TF_BBLUE" "$x" "$TF_RESET"; done
        _tf_section "Registration Modules"
        rg -l 'IServiceCollection' -g '*.cs' . 2>/dev/null | while IFS= read -r f; do
            local count="$(rg 'AddScoped|AddTransient|AddSingleton|AddDbContext|AddHttpClient|AddGrpc' "$f" 2>/dev/null | wc -l | tr -d ' ')"
            (( count > 0 )) && printf '  %s%-55s%s %s%s%s registrations\n' "$TF_BBLUE" "$f" "$TF_RESET" "$TF_BCYAN" "$count" "$TF_RESET"
        done
        ;;

    endpoints|api)
        _tf_title "APPLICATION ENDPOINT SURFACE"
        _tf_section "Minimal API"
        rg -n 'Map(Get|Post|Put|Patch|Delete|Methods)\(' -g '*.cs' . 2>/dev/null | head -100
        _tf_section "Controllers"
        rg -n '\[(HttpGet|HttpPost|HttpPut|HttpPatch|HttpDelete|Route)' -g '*.cs' . 2>/dev/null | head -100
        _tf_section "gRPC"
        rg -n 'MapGrpcService|BindService|GrpcService' -g '*.cs' . 2>/dev/null | head -100
        ;;

    migrations|mig)
        _tf_title "EF MIGRATION MAP"
        local dirs="$(fd -t d -i migrations)"
        [[ -z "$dirs" ]] && { _tf_warn "migrations" "none found"; return; }
        while IFS= read -r dir; do
            printf '\n  %s%s%s\n' "$TF_BMAGENTA" "$dir" "$TF_RESET"
            _tf_label "migration files"; _tf_value "$(fd -e cs . "$dir" 2>/dev/null | rg -v '\.Designer\.cs$|Snapshot\.cs$' | wc -l | tr -d ' ')"
            _tf_label "CreateTable"; _tf_value "$(rg 'CreateTable' "$dir" -g '*.cs' 2>/dev/null | wc -l | tr -d ' ')"
            _tf_label "Add/Alter"; _tf_value "$(rg 'AlterColumn|AddColumn' "$dir" -g '*.cs' 2>/dev/null | wc -l | tr -d ' ')"
            _tf_label "Drop"; _tf_value "$(rg 'DropTable|DropColumn' "$dir" -g '*.cs' 2>/dev/null | wc -l | tr -d ' ')"
        done <<< "$dirs"
        ;;

    analyze|analysis)
        _tf_title ".NET READ-ONLY ANALYSIS"
        _tf_section "Available Analyzers"

        if command -v dotnet >/dev/null 2>&1; then
            _tf_ok "dotnet" "$(dotnet --version 2>/dev/null)"
            _tf_section "Package Vulnerabilities"
            # This is a read-only metadata query; it may restore metadata depending on SDK state.
            dotnet list package --vulnerable --include-transitive 2>/dev/null || _tf_warn "package audit" "could not query"
            _tf_section "Format / Analyzer Verification"
            _tf_dim "Running: dotnet format --verify-no-changes --no-restore"
            dotnet format --verify-no-changes --no-restore 2>&1 | head -80
        else
            _tf_warn "dotnet" "not available"
        fi

        if command -v roslynator >/dev/null 2>&1; then
            _tf_section "Roslynator"
            _tf_ok "Roslynator" "available"
            _tf_dim "Use 'roslynator analyze <solution-or-project>' for deeper Roslyn analysis."
        else
            _tf_warn "Roslynator" "optional; not installed"
        fi

        if command -v csharpier >/dev/null 2>&1; then
            _tf_ok "CSharpier" "available"
        else
            _tf_warn "CSharpier" "optional; not installed"
        fi
        ;;

    why)
        local thing="$1"
        [[ -z "$thing" ]] && { echo "Usage: tfcs why <symbol|context|config|package>"; return 1; }
        _tf_title "EVIDENCE: $thing"
        _tf_section "Source References"
        rg -n -i -- "$thing" -g '*.cs' -g '*.csproj' -g '*.json' -g '*.props' -g '*.targets' . 2>/dev/null | head -100
        _tf_section "Interpretation"
        rg -q "class[[:space:]]+$thing.*DbContext" -g '*.cs' . 2>/dev/null && _tf_found "EF DbContext declaration"
        rg -q "GetConnectionString\\(\"$thing\"\\)" -g '*.cs' . 2>/dev/null && _tf_found "connection-string key"
        rg -q "<PackageReference[^>]*$thing|<PackageVersion[^>]*$thing" -g '*.csproj' -g '*.props' . 2>/dev/null && _tf_found "NuGet dependency"
        ;;

    raw)
        local what="$1"
        case "$what" in
            deps) rg -n '<ProjectReference|<PackageReference|<PackageVersion' -g '*.csproj' -g '*.props' . ;;
            db) rg -n 'DbContext|DbSet<|GetConnectionString|ConnectionStrings|UseSqlServer|UseNpgsql|SqlConnection|NpgsqlConnection|Dapper' -g '*.cs' -g '*.json' . ;;
            config) rg -n 'IConfiguration|GetConnectionString|GetSection|GetValue|IOptions|AddJsonFile|AddEnvironmentVariables|AddUserSecrets' -g '*.cs' . ;;
            di) rg -n 'AddScoped|AddTransient|AddSingleton|IServiceCollection|GetRequiredService' -g '*.cs' . ;;
            *) echo "tfcs raw {deps|db|config|di}" ;;
        esac
        ;;

    stats)
        _tf_need tokei || return
        tokei .
        ;;

    tools)
        _tf_title "TFCS TOOLING"
        _tf_section "Core"
        _tf_tool_status rg "ripgrep"
        _tf_tool_status fd "fd"
        _tf_tool_status tokei "tokei"
        _tf_tool_status jq "jq"
        _tf_section ".NET-aware"
        _tf_tool_status dotnet ".NET SDK"
        _tf_tool_status roslynator "Roslynator"
        _tf_tool_status csharpier "CSharpier"
        printf '\n  %sRecommended additions from the .NET ecosystem:%s\n' "$TF_BOLD" "$TF_RESET"
        printf '    %sRoslynator%s   Roslyn-powered analyzers/refactorings\n' "$TF_BMAGENTA" "$TF_RESET"
        printf '    %sCSharpier%s    deterministic C# formatter (kept optional/read-only here)\n' "$TF_BMAGENTA" "$TF_RESET"
        printf '    %sArchUnitNET%s  useful inside tests for enforceable architecture rules\n' "$TF_BMAGENTA" "$TF_RESET"
        printf '    %sNsDepCop%s     namespace dependency rules (project analyzer, not a shell prerequisite)\n' "$TF_BMAGENTA" "$TF_RESET"
        ;;

    all)
        tfcs summary
        tfcs map
        tfcs db
        tfcs config
        ;;

    help|-h|--help)
        cat <<'EOF'
tfcs - smart C#/.NET project archaeology

  tfcs                  Smart executive summary
  tfcs map              Interpreted project architecture
  tfcs db               DbContext/database/config map
  tfcs deps             Interpreted dependencies
  tfcs config           Configuration provenance
  tfcs services         Dependency injection map
  tfcs endpoints        HTTP/gRPC surface
  tfcs migrations       Migration summary
  tfcs analyze          Read-only SDK/analyzer checks
  tfcs why NAME         Evidence behind an inference
  tfcs raw deps         Raw dependency evidence
  tfcs raw db           Raw database evidence
  tfcs raw config       Raw configuration evidence
  tfcs raw di           Raw DI evidence
  tfcs tools            Tool availability/recommendations
  tfcs stats            Tokei
  tfcs all              Main smart reports
EOF
        ;;
    *) echo "tfcs: unknown command '$cmd'"; echo "Run: tfcs help"; return 1 ;;
    esac
}

# ============================================================================
# JAVASCRIPT / TYPESCRIPT
# ============================================================================

tfjs() {
    local cmd="${1:-summary}"
    [[ $# -gt 0 ]] && shift
    _tf_need rg || return
    _tf_need fd || return

    case "$cmd" in
    summary|overview|ov)
        _tf_title "JS / TYPESCRIPT PROJECT AUTOPSY"
        _tf_section "Project"
        _tf_item "JavaScript" "$(fd -e js --exclude node_modules | wc -l | tr -d ' ') files"
        _tf_item "TypeScript" "$(fd -e ts --exclude node_modules | wc -l | tr -d ' ') files"
        _tf_item "JSX" "$(fd -e jsx --exclude node_modules | wc -l | tr -d ' ') files"
        _tf_item "TSX" "$(fd -e tsx --exclude node_modules | wc -l | tr -d ' ') files"
        _tf_item "packages" "$(fd '^package\.json$' --exclude node_modules | wc -l | tr -d ' ')"
        [[ -f pnpm-lock.yaml ]] && _tf_ok "package manager" "pnpm"
        [[ -f yarn.lock ]] && _tf_ok "package manager" "yarn"
        [[ -f package-lock.json ]] && _tf_ok "package manager" "npm"
        [[ -f bun.lock || -f bun.lockb ]] && _tf_ok "package manager" "Bun"
        fd 'pnpm-workspace\.yaml|turbo\.json|nx\.json|lerna\.json' --exclude node_modules | grep -q . && _tf_found "Monorepo/workspace"
        _tf_git

        _tf_section "Frameworks"
        rg -q '"next"' -g package.json . 2>/dev/null && _tf_framework "Next.js"
        rg -q '"@nestjs/' -g package.json . 2>/dev/null && _tf_framework "NestJS"
        rg -q '"express"' -g package.json . 2>/dev/null && _tf_framework "Express"
        rg -q '"fastify"' -g package.json . 2>/dev/null && _tf_framework "Fastify"
        rg -q '"react"' -g package.json . 2>/dev/null && _tf_framework "React"
        rg -q '"vue"' -g package.json . 2>/dev/null && _tf_framework "Vue"
        rg -q '"@angular/' -g package.json . 2>/dev/null && _tf_framework "Angular"
        rg -q '"svelte"' -g package.json . 2>/dev/null && _tf_framework "Svelte"
        rg -q '"hono"' -g package.json . 2>/dev/null && _tf_framework "Hono"

        _tf_section "Data"
        rg -q '"@prisma/client"|"prisma"' -g package.json . 2>/dev/null && _tf_tech "Prisma"
        rg -q '"drizzle-orm"' -g package.json . 2>/dev/null && _tf_tech "Drizzle"
        rg -q '"typeorm"' -g package.json . 2>/dev/null && _tf_tech "TypeORM"
        rg -q '"sequelize"' -g package.json . 2>/dev/null && _tf_tech "Sequelize"
        rg -q '"mongoose"|"mongodb"' -g package.json . 2>/dev/null && _tf_database "MongoDB"
        rg -q '"pg"|"postgres"' -g package.json . 2>/dev/null && _tf_database "PostgreSQL"
        rg -q '"mysql2"|"mysql"' -g package.json . 2>/dev/null && _tf_database "MySQL"
        rg -q '"redis"|"ioredis"' -g package.json . 2>/dev/null && _tf_database "Redis"

        _tf_section "Testing"
        rg -q '"vitest"' -g package.json . 2>/dev/null && _tf_testtech "Vitest"
        rg -q '"jest"' -g package.json . 2>/dev/null && _tf_testtech "Jest"
        rg -q '"playwright"' -g package.json . 2>/dev/null && _tf_testtech "Playwright"
        rg -q '"cypress"' -g package.json . 2>/dev/null && _tf_testtech "Cypress"

        _tf_section "Next"
        printf '  %s%-18s%s %s\n' "$TF_BGREEN" "tfjs map" "$TF_RESET" "workspace/package architecture"
        printf '  %s%-18s%s %s\n' "$TF_BMAGENTA" "tfjs db" "$TF_RESET" "database/ORM map"
        printf '  %s%-18s%s %s\n' "$TF_BBLUE" "tfjs api" "$TF_RESET" "HTTP/API surface"
        printf '  %s%-18s%s %s\n' "$TF_BYELLOW" "tfjs config" "$TF_RESET" "configuration provenance"
        ;;

    map)
        _tf_title "JS / TS PACKAGE MAP"
        while IFS= read -r pkg; do
            printf '\n  %s%s%s\n' "$TF_BGREEN" "$(dirname "$pkg")" "$TF_RESET"
            if command -v jq >/dev/null 2>&1; then
                _tf_label "package"; _tf_value "$(jq -r '.name // "unnamed"' "$pkg" 2>/dev/null)"
                _tf_label "module type"; _tf_value "$(jq -r '.type // "commonjs/default"' "$pkg" 2>/dev/null)"
                _tf_label "runtime deps"; _tf_value "$(jq '(.dependencies // {}) | length' "$pkg" 2>/dev/null)"
                jq -e '.dependencies.next // .devDependencies.next' "$pkg" >/dev/null 2>&1 && { _tf_label "framework"; _tf_value "Next.js"; }
                jq -e '.dependencies["@nestjs/core"] // .devDependencies["@nestjs/core"]' "$pkg" >/dev/null 2>&1 && { _tf_label "framework"; _tf_value "NestJS"; }
                jq -e '.dependencies.express // .devDependencies.express' "$pkg" >/dev/null 2>&1 && { _tf_label "framework"; _tf_value "Express"; }
            else
                _tf_warn "jq" "install for smart package analysis"
            fi
        done < <(fd '^package\.json$' --exclude node_modules)
        ;;

    db)
        _tf_title "JS / TS DATA MAP"
        _tf_section "ORM / Database Technologies"
        local r
        for r in \
            'PrismaClient|Prisma' 'drizzle\(|Drizzle' 'DataSource\(|TypeORM' \
            'Sequelize|Sequelize' 'mongoose|MongoDB/Mongoose' 'MongoClient|MongoDB' \
            'new Pool|PostgreSQL' 'mysql2|MySQL' 'ioredis|Redis' 'better-sqlite3|SQLite'; do
            local pattern="${r%%|*}" label="${r#*|}"
            local count="$(rg -l "$pattern" -g '*.js' -g '*.ts' -g '*.tsx' -g package.json --glob '!node_modules/**' . 2>/dev/null | wc -l | tr -d ' ')"
            (( count > 0 )) && _tf_item "$label" "$count evidence files"
        done
        _tf_section "Schemas"
        fd 'schema\.prisma|drizzle.*config|knexfile|sequelize|migrations' --exclude node_modules |
            while IFS= read -r f; do printf '  %s%s%s\n' "$TF_BBLUE" "$f" "$TF_RESET"; done
        _tf_section "Database Configuration Keys"
        rg -o 'DATABASE_URL|DB_HOST|DB_PORT|DB_NAME|DB_USER|MONGO_URI|REDIS_URL' \
            -g '*.js' -g '*.ts' -g '*.tsx' -g '*.env*' --hidden --glob '!node_modules/**' . 2>/dev/null |
            sort -u | while IFS= read -r x; do printf '  %s%s%s\n' "$TF_BYELLOW" "$x" "$TF_RESET"; done
        ;;

    api|endpoints)
        _tf_title "JS / TS API SURFACE"
        _tf_section "HTTP Routes"
        rg -n '\.(get|post|put|patch|delete)\s*\(|@(Get|Post|Put|Patch|Delete)\(' \
            -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . 2>/dev/null | head -100
        _tf_section "Outbound HTTP"
        _tf_item "fetch()" "$(_tf_count_matches 'fetch\(' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**') calls"
        _tf_item "axios" "$(_tf_count_matches 'axios\.|axios\(' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**') calls"
        rg -q 'ApolloServer|GraphQL|@Resolver|gql`' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . 2>/dev/null && _tf_found "GraphQL" || _tf_dim "No obvious GraphQL usage."
        ;;

    config|conf|env)
        _tf_title "JS / TS CONFIGURATION MAP"
        _tf_section "Environment Files"
        fd '^\.env($|\.)' --hidden --exclude node_modules | while IFS= read -r f; do printf '  %s%s%s\n' "$TF_BBLUE" "$f" "$TF_RESET"; done
        _tf_section "Environment Variables Used"
        {
            rg -o 'process\.env\.[A-Za-z_][A-Za-z0-9_]*' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . 2>/dev/null | sed 's/.*process\.env\.//'
            rg -o 'import\.meta\.env\.[A-Za-z_][A-Za-z0-9_]*' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . 2>/dev/null | sed 's/.*import\.meta\.env\.//'
        } | sort -u | while IFS= read -r x; do printf '  %s%s%s\n' "$TF_BYELLOW" "$x" "$TF_RESET"; done
        _tf_section "Configuration Technologies"
        rg -q 'dotenv' -g package.json -g '*.js' -g '*.ts' . 2>/dev/null && _tf_found "dotenv"
        rg -q 'ConfigModule|ConfigService' -g '*.ts' . 2>/dev/null && _tf_found "NestJS Config"
        fd 'vite\.config\.' --exclude node_modules | grep -q . && _tf_found "Vite config"
        fd 'next\.config\.' --exclude node_modules | grep -q . && _tf_found "Next.js config"
        ;;

    scripts)
        _tf_title "PACKAGE EXECUTION MAP"
        _tf_need jq || return
        while IFS= read -r pkg; do
            printf '\n  %s%s%s\n' "$TF_BGREEN" "$pkg" "$TF_RESET"
            if command -v column >/dev/null; then
                jq -r '.scripts // {} | to_entries[] | "    \(.key)\t\(.value)"' "$pkg" 2>/dev/null | column -t -s $'\t'
            else
                jq -r '.scripts // {} | to_entries[] | "    \(.key): \(.value)"' "$pkg" 2>/dev/null
            fi
        done < <(fd '^package\.json$' --exclude node_modules)
        ;;

    deps)
        _tf_title "JS / TS DEPENDENCY SUMMARY"
        _tf_need jq || return
        while IFS= read -r pkg; do
            printf '\n  %s%s%s\n' "$TF_BGREEN" "$pkg" "$TF_RESET"
            _tf_label "runtime deps"; _tf_value "$(jq '(.dependencies // {}) | length' "$pkg")"
            _tf_label "dev deps"; _tf_value "$(jq '(.devDependencies // {}) | length' "$pkg")"
            local t
            for t in \
                'next|Next.js' 'react|React' '@nestjs/core|NestJS' 'express|Express' \
                'fastify|Fastify' '@prisma/client|Prisma' 'drizzle-orm|Drizzle' \
                'typeorm|TypeORM' 'mongoose|Mongoose' 'pg|PostgreSQL' 'redis|Redis' \
                'ioredis|Redis' 'amqplib|RabbitMQ' 'kafkajs|Kafka' 'vitest|Vitest' \
                'jest|Jest' '@playwright/test|Playwright'; do
                local dep="${t%%|*}" label="${t#*|}"
                if jq -e --arg d "$dep" '(.dependencies[$d] // .devDependencies[$d]) != null' "$pkg" >/dev/null 2>&1; then
                    _tf_label "$label"; _tf_value "$(jq -r --arg d "$dep" '.dependencies[$d] // .devDependencies[$d]' "$pkg")"
                fi
            done
        done < <(fd '^package\.json$' --exclude node_modules)
        ;;

    why)
        local thing="$1"
        [[ -z "$thing" ]] && { echo "Usage: tfjs why <package|symbol|env|technology>"; return 1; }
        _tf_title "EVIDENCE: $thing"
        rg -n -i -- "$thing" -g '*.js' -g '*.jsx' -g '*.ts' -g '*.tsx' -g '*.json' -g '*.yaml' -g '*.yml' -g '*.env*' --hidden --glob '!node_modules/**' . 2>/dev/null | head -100
        _tf_section "Interpretation"
        rg -q "\"$thing\"" -g package.json . 2>/dev/null && _tf_found "Declared npm dependency"
        rg -q "process\\.env\\.$thing|import\\.meta\\.env\\.$thing" -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . 2>/dev/null && _tf_found "Environment/configuration key"
        ;;

    raw)
        local what="$1"
        case "$what" in
            deps) rg -n '"dependencies"|"devDependencies"|"peerDependencies"' -g package.json . ;;
            db) rg -n 'PrismaClient|drizzle|DataSource|Sequelize|mongoose|MongoClient|DATABASE_URL|DB_HOST|Redis|createPool' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . ;;
            config) rg -n 'process\.env|import\.meta\.env|dotenv|ConfigService|loadEnv' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . ;;
            api) rg -n '\.(get|post|put|patch|delete)\s*\(|@(Get|Post|Put|Patch|Delete)\(|fetch\(|axios' -g '*.js' -g '*.ts' -g '*.tsx' --glob '!node_modules/**' . ;;
            *) echo "tfjs raw {deps|db|config|api}" ;;
        esac
        ;;

    stats)
        _tf_need tokei || return
        tokei . --exclude node_modules
        ;;
    tools)
        _tf_title "TFJS TOOLING"
        _tf_tool_status rg "ripgrep"; _tf_tool_status fd "fd"; _tf_tool_status tokei "tokei"
        _tf_tool_status jq "jq"; _tf_tool_status node "Node.js"; _tf_tool_status npm "npm"
        _tf_tool_status pnpm "pnpm"; _tf_tool_status bun "Bun"
        ;;
    all)
        tfjs summary
        tfjs map
        tfjs db
        tfjs config
        ;;
    help|-h|--help)
        cat <<'EOF'
tfjs - smart JavaScript/TypeScript project archaeology

  tfjs                  Smart executive summary
  tfjs map              Package/workspace map
  tfjs db               Database/ORM map
  tfjs api              HTTP/API surface
  tfjs config           Environment/config provenance
  tfjs scripts          package.json execution map
  tfjs deps             Interpreted dependencies
  tfjs why NAME         Evidence behind inference
  tfjs raw deps         Raw dependencies
  tfjs raw db           Raw database evidence
  tfjs raw config       Raw configuration evidence
  tfjs raw api          Raw API evidence
  tfjs tools            Tool availability
  tfjs stats            Tokei
  tfjs all              Main smart reports
EOF
        ;;
    *) echo "tfjs: unknown command '$cmd'"; echo "Run: tfjs help"; return 1 ;;
    esac
}
# ============================================================================
# TFX - XML PROJECT ARCHAEOLOGY
# ============================================================================
#
# Recommended:
#   sudo dnf install xmlstarlet
#
# Optional:
#   yq
#
# Usage:
#   tfx
#   tfx map
#   tfx file foo.xml
#   tfx tree foo.xml
#   tfx attrs foo.xml
#   tfx values foo.xml
#   tfx namespaces foo.xml
#   tfx refs
#   tfx schemas
#   tfx validate
#   tfx xpath foo.xml '//Thing/@Name'
#   tfx convert foo.xml
#   tfx why ConnectionString
#   tfx raw foo.xml
#   tfx tools
#
# Also understands:
#   .csproj .props .targets .xml .config .xsd .wsdl .resx .nuspec
#
# Read-only. No XML files are modified.
# ============================================================================


# ----------------------------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------------------------

_tfx_is_xml_file() {
    case "$1" in
        *.xml|*.config|*.csproj|*.props|*.targets|*.xsd|*.wsdl|*.resx|*.nuspec)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


_tfx_files() {
    fd \
        -t f \
        -e xml \
        -e config \
        -e csproj \
        -e props \
        -e targets \
        -e xsd \
        -e wsdl \
        -e resx \
        -e nuspec \
        --exclude bin \
        --exclude obj \
        --exclude node_modules \
        --exclude .git \
        . 2>/dev/null
}


_tfx_xmlstarlet() {
    command -v xmlstarlet >/dev/null 2>&1
}


_tfx_yq() {
    command -v yq >/dev/null 2>&1
}


_tfx_require_xmlstarlet() {
    if ! _tfx_xmlstarlet; then
        _tf_bad "missing tool" "xmlstarlet"
        printf '\n  Install on Fedora/Ultramarine:\n\n'
        printf '    %ssudo dnf install xmlstarlet%s\n\n' \
            "$TF_BCYAN" "$TF_RESET"
        return 1
    fi
}


_tfx_root() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'name(/*)' \
        "$file" \
        2>/dev/null
}


_tfx_namespace_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -m '/*/namespace::*' \
        -v 'name()' \
        -n \
        "$file" \
        2>/dev/null |
        sort -u |
        grep -v '^xml$' |
        wc -l |
        tr -d ' '
}


_tfx_element_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//*)' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_attribute_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//@*)' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_type() {
    local file="$1"
    local base=""

    base="$(basename "$file")"

    case "$file" in

        *.csproj)
            printf 'MSBuild project'
            ;;

        *Directory.Packages.props)
            printf 'Central NuGet versions'
            ;;

        *Directory.Build.props)
            printf 'MSBuild shared properties'
            ;;

        *Directory.Build.targets)
            printf 'MSBuild shared targets'
            ;;

        *.props)
            printf 'MSBuild properties'
            ;;

        *.targets)
            printf 'MSBuild targets'
            ;;

        *.xsd)
            printf 'XML Schema'
            ;;

        *.wsdl)
            printf 'WSDL / SOAP contract'
            ;;

        *.resx)
            printf '.NET resources'
            ;;

        *.nuspec)
            printf 'NuGet package specification'
            ;;

        *.config)
            if rg -q \
                '<configuration([ >])' \
                "$file" \
                2>/dev/null
            then
                printf '.NET configuration'
            else
                printf 'XML configuration'
            fi
            ;;

        *.xml)
            printf 'XML document'
            ;;

        *)
            printf 'XML-like document'
            ;;

    esac
}


_tfx_msbuild_sdk() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v '/*[local-name()="Project"]/@Sdk' \
        "$file" \
        2>/dev/null
}


_tfx_msbuild_package_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//*[local-name()="PackageReference"])' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_msbuild_projectref_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//*[local-name()="ProjectReference"])' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_msbuild_import_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//*[local-name()="Import"])' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_msbuild_property_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//*[local-name()="PropertyGroup"]/*)' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_msbuild_target_count() {
    local file="$1"

    xmlstarlet sel \
        -t \
        -v 'count(//*[local-name()="Target"])' \
        "$file" \
        2>/dev/null |
        sed 's/\..*$//'
}


_tfx_validate_file() {
    local file="$1"

    xmlstarlet val \
        -q \
        "$file" \
        >/dev/null 2>&1
}


# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------

tfx() {

    local cmd="${1:-summary}"

    [[ $# -gt 0 ]] && shift

    _tf_need fd || return
    _tf_need rg || return


    case "$cmd" in


    # ========================================================================
    # SUMMARY
    # ========================================================================

    summary|overview|ov)

        _tf_title "XML PROJECT AUTOPSY"

        _tf_section "Landscape"

        local total=0
        local xml=0
        local config=0
        local csproj=0
        local props=0
        local targets=0
        local xsd=0
        local wsdl=0
        local resx=0
        local nuspec=0

        total="$(_tfx_files | wc -l | tr -d ' ')"

        xml="$(fd -e xml \
            --exclude bin \
            --exclude obj \
            --exclude node_modules |
            wc -l |
            tr -d ' ')"

        config="$(fd -e config \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        csproj="$(fd -e csproj \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        props="$(fd -e props \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        targets="$(fd -e targets \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        xsd="$(fd -e xsd \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        wsdl="$(fd -e wsdl \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        resx="$(fd -e resx \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"

        nuspec="$(fd -e nuspec \
            --exclude bin \
            --exclude obj |
            wc -l |
            tr -d ' ')"


        _tf_item "XML-like files" "$total"

        (( csproj > 0 )) &&
            _tf_item ".csproj" "$csproj"

        (( props > 0 )) &&
            _tf_item ".props" "$props"

        (( targets > 0 )) &&
            _tf_item ".targets" "$targets"

        (( xml > 0 )) &&
            _tf_item ".xml" "$xml"

        (( config > 0 )) &&
            _tf_item ".config" "$config"

        (( xsd > 0 )) &&
            _tf_item ".xsd" "$xsd"

        (( wsdl > 0 )) &&
            _tf_item ".wsdl" "$wsdl"

        (( resx > 0 )) &&
            _tf_item ".resx" "$resx"

        (( nuspec > 0 )) &&
            _tf_item ".nuspec" "$nuspec"


        # --------------------------------------------------------------------
        # CLASSIFY
        # --------------------------------------------------------------------

        _tf_section "Detected XML Technologies"


        (( csproj > 0 )) &&
            _tf_framework "MSBuild projects"


        if fd \
            '^Directory\.Packages\.props$' \
            --exclude bin \
            --exclude obj |
            grep -q .
        then
            _tf_tech "Central Package Management"
        fi


        if fd \
            '^Directory\.Build\.props$' \
            --exclude bin \
            --exclude obj |
            grep -q .
        then
            _tf_tech "Directory.Build.props"
        fi


        if fd \
            '^Directory\.Build\.targets$' \
            --exclude bin \
            --exclude obj |
            grep -q .
        then
            _tf_tech "Directory.Build.targets"
        fi


        (( xsd > 0 )) &&
            _tf_tech "XML Schema / XSD"


        (( wsdl > 0 )) &&
            _tf_tech "SOAP / WSDL"


        (( resx > 0 )) &&
            _tf_tech ".NET RESX resources"


        (( nuspec > 0 )) &&
            _tf_tech "NuGet package specs"


        if rg -q \
            '<configuration([ >])' \
            -g '*.config' \
            . 2>/dev/null
        then
            _tf_tech "Legacy .NET configuration"
        fi


        if rg -q \
            '<appSettings([ >])|<connectionStrings([ >])' \
            -g '*.config' \
            -g '*.xml' \
            . 2>/dev/null
        then
            _tf_warn "legacy config" \
                "appSettings / connectionStrings"
        fi


        if rg -q \
            'xmlns(:[^=]+)?=["'\'']http://schemas\.xmlsoap\.org' \
            -g '*.xml' \
            -g '*.config' \
            -g '*.wsdl' \
            . 2>/dev/null
        then
            _tf_tech "SOAP namespace"
        fi


        # --------------------------------------------------------------------
        # TOOLING
        # --------------------------------------------------------------------

        _tf_section "Parser"

        if _tfx_xmlstarlet; then
            _tf_ok "XMLStarlet" "structural XML parsing enabled"
        else
            _tf_warn "XMLStarlet" \
                "not installed - structural commands unavailable"
        fi


        if _tfx_yq; then
            _tf_ok "yq" "XML conversion available"
        else
            _tf_item "yq" "optional"
        fi


        # --------------------------------------------------------------------
        # NEXT
        # --------------------------------------------------------------------

        _tf_section "Next"

        printf '  %s%-20s%s %s\n' \
            "$TF_BGREEN" \
            "tfx map" \
            "$TF_RESET" \
            "classify every XML file"

        printf '  %s%-20s%s %s\n' \
            "$TF_BMAGENTA" \
            "tfx msbuild" \
            "$TF_RESET" \
            "understand .NET XML"

        printf '  %s%-20s%s %s\n' \
            "$TF_BYELLOW" \
            "tfx refs" \
            "$TF_RESET" \
            "find XML relationships"

        printf '  %s%-20s%s %s\n' \
            "$TF_BBLUE" \
            "tfx schemas" \
            "$TF_RESET" \
            "find schemas/namespaces"

        printf '  %s%-20s%s %s\n' \
            "$TF_BCYAN" \
            "tfx validate" \
            "$TF_RESET" \
            "check well-formedness"

        ;;


    # ========================================================================
    # MAP
    # ========================================================================

    map)

        _tfx_require_xmlstarlet || return

        _tf_title "XML FILE MAP"

        while IFS= read -r file; do

            (
                local type=""
                local root=""
                local elements=0
                local attrs=0
                local namespaces=0

                type="$(_tfx_type "$file")"
                root="$(_tfx_root "$file")"

                if [[ -z "$root" ]]; then

                    printf '\n  %s%s%s\n' \
                        "$TF_BRED" \
                        "$file" \
                        "$TF_RESET"

                    _tf_label "status"

                    printf '%sinvalid XML%s\n' \
                        "$TF_BRED" \
                        "$TF_RESET"

                    exit 0

                fi


                elements="$(_tfx_element_count "$file")"
                attrs="$(_tfx_attribute_count "$file")"
                namespaces="$(_tfx_namespace_count "$file")"


                printf '\n  %s%s%s\n' \
                    "$TF_BBLUE" \
                    "$file" \
                    "$TF_RESET"


                _tf_label "type"
                _tf_value "$type"


                _tf_label "root"
                _tf_dbval "$root"


                _tf_label "elements"
                _tf_value "${elements:-0}"


                _tf_label "attributes"
                _tf_value "${attrs:-0}"


                if (( namespaces > 0 )); then
                    _tf_label "namespaces"
                    _tf_value "$namespaces"
                fi


                # ------------------------------------------------------------
                # MSBUILD DETAILS
                # ------------------------------------------------------------

                case "$file" in

                    *.csproj|*.props|*.targets)

                        local sdk=""
                        local packages=0
                        local projectrefs=0
                        local imports=0
                        local targets=0

                        sdk="$(_tfx_msbuild_sdk "$file")"

                        packages="$(
                            _tfx_msbuild_package_count "$file"
                        )"

                        projectrefs="$(
                            _tfx_msbuild_projectref_count "$file"
                        )"

                        imports="$(
                            _tfx_msbuild_import_count "$file"
                        )"

                        targets="$(
                            _tfx_msbuild_target_count "$file"
                        )"


                        if [[ -n "$sdk" ]]; then
                            _tf_label "SDK"
                            _tf_cfgval "$sdk"
                        fi


                        (( packages > 0 )) && {
                            _tf_label "packages"
                            _tf_value "$packages"
                        }


                        (( projectrefs > 0 )) && {
                            _tf_label "project refs"
                            _tf_value "$projectrefs"
                        }


                        (( imports > 0 )) && {
                            _tf_label "imports"
                            _tf_value "$imports"
                        }


                        (( targets > 0 )) && {
                            _tf_label "targets"
                            _tf_value "$targets"
                        }

                        ;;

                esac

            )

        done < <(_tfx_files | sort)

        ;;


    # ========================================================================
    # SINGLE FILE SUMMARY
    # ========================================================================

    file|inspect)

        _tfx_require_xmlstarlet || return

        local file="$1"

        if [[ -z "$file" ]]; then
            echo "Usage: tfx file <file>"
            return 1
        fi


        if [[ ! -f "$file" ]]; then
            _tf_bad "file" "not found: $file"
            return 1
        fi


        _tf_title "XML INSPECTOR"

        _tf_section "$(basename "$file")"


        if ! _tfx_validate_file "$file"; then
            _tf_bad "XML" "not well-formed"
            return 1
        fi


        _tf_label "path"
        _tf_pathval "$file"


        _tf_label "type"
        _tf_value "$(_tfx_type "$file")"


        _tf_label "root"
        _tf_dbval "$(_tfx_root "$file")"


        _tf_label "elements"
        _tf_value "$(_tfx_element_count "$file")"


        _tf_label "attributes"
        _tf_value "$(_tfx_attribute_count "$file")"


        _tf_label "namespaces"
        _tf_value "$(_tfx_namespace_count "$file")"


        case "$file" in

            *.csproj|*.props|*.targets)

                local sdk=""
                sdk="$(_tfx_msbuild_sdk "$file")"


                [[ -n "$sdk" ]] && {
                    _tf_label "SDK"
                    _tf_cfgval "$sdk"
                }


                _tf_label "packages"
                _tf_value "$(_tfx_msbuild_package_count "$file")"


                _tf_label "project refs"
                _tf_value "$(_tfx_msbuild_projectref_count "$file")"


                _tf_label "properties"
                _tf_value "$(_tfx_msbuild_property_count "$file")"


                _tf_label "imports"
                _tf_value "$(_tfx_msbuild_import_count "$file")"


                _tf_label "targets"
                _tf_value "$(_tfx_msbuild_target_count "$file")"

                ;;

        esac

        ;;


    # ========================================================================
    # MSBUILD
    # ========================================================================

    msbuild|dotnet)

        _tfx_require_xmlstarlet || return

        _tf_title "MSBUILD XML MAP"


        # --------------------------------------------------------------------
        # GLOBAL FILES
        # --------------------------------------------------------------------

        _tf_section "Global Build Configuration"


        local globals=""

        globals="$(
            fd \
                '^(Directory\.Build\.(props|targets)|Directory\.Packages\.props|NuGet\.Config)$' \
                --exclude bin \
                --exclude obj \
                . 2>/dev/null
        )"


        if [[ -n "$globals" ]]; then

            while IFS= read -r file; do

                printf '  %s%s%s\n' \
                    "$TF_BMAGENTA" \
                    "$file" \
                    "$TF_RESET"

            done <<< "$globals"

        else

            _tf_dim "No global MSBuild XML detected."

        fi


        # --------------------------------------------------------------------
        # PROJECTS
        # --------------------------------------------------------------------

        _tf_section "Projects"


        while IFS= read -r file; do

            (
                local name=""
                local sdk=""
                local packages=0
                local projectrefs=0
                local imports=0

                name="$(basename "$file" .csproj)"

                sdk="$(_tfx_msbuild_sdk "$file")"

                packages="$(
                    _tfx_msbuild_package_count "$file"
                )"

                projectrefs="$(
                    _tfx_msbuild_projectref_count "$file"
                )"

                imports="$(
                    _tfx_msbuild_import_count "$file"
                )"


                printf '\n  %s%s%s%s\n' \
                    "$TF_BOLD" \
                    "$TF_BGREEN" \
                    "$name" \
                    "$TF_RESET"


                _tf_label "file"
                _tf_pathval "$file"


                [[ -n "$sdk" ]] && {
                    _tf_label "SDK"
                    _tf_cfgval "$sdk"
                }


                _tf_label "package refs"
                _tf_value "$packages"


                _tf_label "project refs"
                _tf_value "$projectrefs"


                (( imports > 0 )) && {
                    _tf_label "imports"
                    _tf_value "$imports"
                }


                # ------------------------------------------------------------
                # TARGET FRAMEWORK
                # ------------------------------------------------------------

                local framework=""

                framework="$(
                    xmlstarlet sel \
                        -t \
                        -v \
                        '//*[local-name()="TargetFramework"][1]' \
                        "$file" \
                        2>/dev/null
                )"


                if [[ -z "$framework" ]]; then

                    framework="$(
                        xmlstarlet sel \
                            -t \
                            -v \
                            '//*[local-name()="TargetFrameworks"][1]' \
                            "$file" \
                            2>/dev/null
                    )"

                fi


                [[ -n "$framework" ]] && {
                    _tf_label "framework"
                    _tf_value "$framework"
                }


                # ------------------------------------------------------------
                # PROJECT REFERENCES
                # ------------------------------------------------------------

                if (( projectrefs > 0 )); then

                    _tf_label "depends on"
                    printf '\n'


                    xmlstarlet sel \
                        -t \
                        -m \
                        '//*[local-name()="ProjectReference"]' \
                        -v '@Include' \
                        -n \
                        "$file" \
                        2>/dev/null |
                    while IFS= read -r ref; do

                        ref="${ref//\\//}"

                        printf '        %s└─%s %s%s%s\n' \
                            "$TF_DIM" \
                            "$TF_RESET" \
                            "$TF_BBLUE" \
                            "$(basename "$ref" .csproj)" \
                            "$TF_RESET"

                    done

                fi

            )

        done < <(
            fd \
                -e csproj \
                --exclude bin \
                --exclude obj \
                . |
            sort
        )


        # --------------------------------------------------------------------
        # CENTRAL PACKAGES
        # --------------------------------------------------------------------

        local central=""

        central="$(
            fd \
                '^Directory\.Packages\.props$' \
                --exclude bin \
                --exclude obj \
                . |
            head -1
        )"


        if [[ -n "$central" ]]; then

            _tf_section "Central Package Versions"


            local package_count=""

            package_count="$(
                xmlstarlet sel \
                    -t \
                    -v \
                    'count(//*[local-name()="PackageVersion"])' \
                    "$central" \
                    2>/dev/null |
                sed 's/\..*$//'
            )"


            _tf_label "file"
            _tf_pathval "$central"


            _tf_label "packages"
            _tf_value "${package_count:-0}"


            xmlstarlet sel \
                -t \
                -m \
                '//*[local-name()="PackageVersion"]' \
                -v '@Include' \
                -o '|' \
                -v '@Version' \
                -n \
                "$central" \
                2>/dev/null |
            sort |
            while IFS='|' read -r package version; do

                printf '  %s%-45s%s %s%s%s\n' \
                    "$TF_BMAGENTA" \
                    "$package" \
                    "$TF_RESET" \
                    "$TF_BCYAN" \
                    "$version" \
                    "$TF_RESET"

            done

        fi

        ;;


    # ========================================================================
    # TREE
    # ========================================================================

    tree|elements)

        _tfx_require_xmlstarlet || return

        local file="$1"

        [[ -z "$file" ]] && {
            echo "Usage: tfx tree <file>"
            return 1
        }


        [[ ! -f "$file" ]] && {
            _tf_bad "file" "not found: $file"
            return 1
        }


        _tf_title "XML ELEMENT TREE"

        _tf_section "$file"


        # xmlstarlet el produces paths such as:
        #
        # Project
        # Project/PropertyGroup
        # Project/ItemGroup/PackageReference
        #
        # Collapse duplicates so giant files remain useful.

        xmlstarlet el \
            "$file" \
            2>/dev/null |
        sed 's/@.*$//' |
        sort -u |
        while IFS= read -r path; do

            local depth=0
            local name=""
            local indent=""

            depth="$(
                printf '%s' "$path" |
                awk -F/ '{print NF-1}'
            )"

            name="${path##*/}"

            indent="$(
                printf '%*s' "$((depth * 2))" ''
            )"

            printf '  %s%s%s%s\n' \
                "$indent" \
                "$TF_BCYAN" \
                "$name" \
                "$TF_RESET"

        done

        ;;


    # ========================================================================
    # ATTRIBUTES
    # ========================================================================

    attrs|attributes)

        _tfx_require_xmlstarlet || return

        local file="$1"

        [[ -z "$file" ]] && {
            echo "Usage: tfx attrs <file>"
            return 1
        }


        _tf_title "XML ATTRIBUTES"

        _tf_section "$file"


        xmlstarlet sel \
            -t \
            -m '//@*' \
            -v 'name()' \
            -o '|' \
            -v '.' \
            -n \
            "$file" \
            2>/dev/null |
        sort -u |
        while IFS='|' read -r name value; do

            printf '  %s%-28s%s %s%s%s\n' \
                "$TF_BMAGENTA" \
                "$name" \
                "$TF_RESET" \
                "$TF_BCYAN" \
                "$value" \
                "$TF_RESET"

        done

        ;;


    # ========================================================================
    # VALUES
    # ========================================================================

    values|leaves)

        _tfx_require_xmlstarlet || return

        local file="$1"

        [[ -z "$file" ]] && {
            echo "Usage: tfx values <file>"
            return 1
        }


        _tf_title "XML LEAF VALUES"

        _tf_section "$file"


        xmlstarlet sel \
            -t \
            -m '//*[not(*) and normalize-space(.) != ""]' \
            -v 'name()' \
            -o '|' \
            -v 'normalize-space(.)' \
            -n \
            "$file" \
            2>/dev/null |
        while IFS='|' read -r name value; do

            printf '  %s%-28s%s %s%s%s\n' \
                "$TF_BMAGENTA" \
                "$name" \
                "$TF_RESET" \
                "$TF_BCYAN" \
                "$value" \
                "$TF_RESET"

        done

        ;;


    # ========================================================================
    # NAMESPACES
    # ========================================================================

    namespaces|ns)

        _tfx_require_xmlstarlet || return

        local file="$1"

        [[ -z "$file" ]] && {
            echo "Usage: tfx namespaces <file>"
            return 1
        }


        _tf_title "XML NAMESPACES"

        _tf_section "$file"


        xmlstarlet sel \
            -t \
            -m '/*/namespace::*' \
            -v 'name()' \
            -o '|' \
            -v '.' \
            -n \
            "$file" \
            2>/dev/null |
        sort -u |
        while IFS='|' read -r prefix uri; do

            [[ "$prefix" == "xml" ]] && continue

            [[ -z "$prefix" ]] &&
                prefix="(default)"


            printf '  %s%-20s%s %s%s%s\n' \
                "$TF_BMAGENTA" \
                "$prefix" \
                "$TF_RESET" \
                "$TF_BCYAN" \
                "$uri" \
                "$TF_RESET"

        done

        ;;


    # ========================================================================
    # REFERENCES
    # ========================================================================

    refs|references)

        _tf_title "XML REFERENCES"


        # --------------------------------------------------------------------
        # PROJECT REFERENCES
        # --------------------------------------------------------------------

        _tf_section "Project References"


        local found=0


        while IFS= read -r file; do

            [[ -z "$file" ]] && continue

            local hits=""

            hits="$(
                rg -n \
                    '<ProjectReference[^>]+Include=' \
                    "$file" \
                    2>/dev/null
            )"


            [[ -z "$hits" ]] && continue

            found=1


            printf '\n  %s%s%s\n' \
                "$TF_BGREEN" \
                "$file" \
                "$TF_RESET"


            printf '%s\n' "$hits" |
            while IFS= read -r hit; do

                printf '      %s%s%s\n' \
                    "$TF_BBLUE" \
                    "$hit" \
                    "$TF_RESET"

            done

        done < <(
            fd \
                -e csproj \
                --exclude bin \
                --exclude obj
        )


        (( found == 0 )) &&
            _tf_dim "No ProjectReference elements detected."


        # --------------------------------------------------------------------
        # IMPORTS
        # --------------------------------------------------------------------

        _tf_section "Imports"


        rg -n \
            '<Import[^>]+Project=' \
            -g '*.csproj' \
            -g '*.props' \
            -g '*.targets' \
            --glob '!**/bin/**' \
            --glob '!**/obj/**' \
            . 2>/dev/null |
        head -100


        # --------------------------------------------------------------------
        # FILE / URL REFERENCES
        # --------------------------------------------------------------------

        _tf_section "External / File References"


        rg -n \
            '(https?://|file://|\.xsd["'\'']|\.xml["'\'']|\.config["'\'']|schemaLocation=|href=|src=)' \
            -g '*.xml' \
            -g '*.config' \
            -g '*.csproj' \
            -g '*.props' \
            -g '*.targets' \
            -g '*.xsd' \
            -g '*.wsdl' \
            --glob '!**/bin/**' \
            --glob '!**/obj/**' \
            . 2>/dev/null |
        head -150

        ;;


    # ========================================================================
    # SCHEMAS
    # ========================================================================

    schemas|schema)

        _tf_title "XML SCHEMA / NAMESPACE MAP"


        _tf_section "XSD Files"


        local xsds=""

        xsds="$(
            fd \
                -e xsd \
                --exclude bin \
                --exclude obj
        )"


        if [[ -n "$xsds" ]]; then

            while IFS= read -r file; do
                printf '  %s%s%s\n' \
                    "$TF_BMAGENTA" \
                    "$file" \
                    "$TF_RESET"
            done <<< "$xsds"

        else

            _tf_dim "No XSD files detected."

        fi


        _tf_section "Schema References"


        rg -n \
            'schemaLocation|noNamespaceSchemaLocation|\.xsd' \
            -g '*.xml' \
            -g '*.config' \
            -g '*.xsd' \
            -g '*.wsdl' \
            . 2>/dev/null |
        head -150


        _tf_section "Namespace Declarations"


        rg -o \
            'xmlns(:[A-Za-z0-9_.-]+)?="[^"]+"' \
            -g '*.xml' \
            -g '*.config' \
            -g '*.xsd' \
            -g '*.wsdl' \
            -g '*.csproj' \
            -g '*.props' \
            -g '*.targets' \
            . 2>/dev/null |
        sort -u |
        head -150

        ;;


    # ========================================================================
    # VALIDATE
    # ========================================================================

    validate|check)

        _tfx_require_xmlstarlet || return

        _tf_title "XML VALIDATION"

        local good=0
        local bad=0


        while IFS= read -r file; do

            if _tfx_validate_file "$file"; then

                (( good++ ))

                printf '  %s✓%s %s%s%s\n' \
                    "$TF_BGREEN" \
                    "$TF_RESET" \
                    "$TF_BBLUE" \
                    "$file" \
                    "$TF_RESET"

            else

                (( bad++ ))

                printf '  %s✗%s %s%s%s\n' \
                    "$TF_BRED" \
                    "$TF_RESET" \
                    "$TF_BRED" \
                    "$file" \
                    "$TF_RESET"

                xmlstarlet val \
                    "$file" \
                    2>&1 |
                sed 's/^/      /'

            fi

        done < <(_tfx_files)


        _tf_section "Result"

        _tf_ok "valid" "$good"

        if (( bad > 0 )); then
            _tf_bad "invalid" "$bad"
        else
            _tf_ok "invalid" "0"
        fi

        ;;


    # ========================================================================
    # XPATH
    # ========================================================================

    xpath)

        _tfx_require_xmlstarlet || return

        local file="$1"
        local xpath="$2"


        if [[ -z "$file" || -z "$xpath" ]]; then

            echo "Usage:"
            echo "  tfx xpath <file> '<xpath>'"
            echo
            echo "Example:"
            echo "  tfx xpath Foo.csproj '//*[local-name()=\"PackageReference\"]/@Include'"

            return 1

        fi


        _tf_title "XPATH QUERY"

        _tf_label "file"
        _tf_pathval "$file"

        _tf_label "xpath"
        _tf_cfgval "$xpath"

        echo


        xmlstarlet sel \
            -t \
            -m "$xpath" \
            -v '.' \
            -n \
            "$file"

        ;;


    # ========================================================================
    # CONVERT
    # ========================================================================

    convert|yaml|json)

        local file="$1"

        [[ -z "$file" ]] && {
            echo "Usage: tfx convert <file>"
            return 1
        }


        if ! _tfx_yq; then

            _tf_bad "missing tool" "yq"

            printf '\n'
            printf '  XMLStarlet is installed for structural work.\n'
            printf '  Install yq if you also want XML -> YAML/JSON views.\n'

            return 1

        fi


        _tf_title "XML CONVERSION"

        _tf_section "$file"


        # Mike Farah yq v4 supports XML input.
        yq \
            -p=xml \
            -o=yaml \
            '.' \
            "$file"

        ;;


    # ========================================================================
    # WHY
    # ========================================================================

    why)

        local thing="$1"

        [[ -z "$thing" ]] && {
            echo "Usage: tfx why <element|attribute|value|filename>"
            return 1
        }


        _tf_title "XML EVIDENCE: $thing"


        _tf_section "Occurrences"


        local results=""

        results="$(
            rg -n \
                -i \
                -- "$thing" \
                -g '*.xml' \
                -g '*.config' \
                -g '*.csproj' \
                -g '*.props' \
                -g '*.targets' \
                -g '*.xsd' \
                -g '*.wsdl' \
                -g '*.resx' \
                -g '*.nuspec' \
                --glob '!**/bin/**' \
                --glob '!**/obj/**' \
                . 2>/dev/null |
            head -150
        )"


        if [[ -n "$results" ]]; then

            printf '%s\n' "$results"

        else

            _tf_warn "matches" "none"
            return 0

        fi


        # --------------------------------------------------------------------
        # INTERPRETATION
        # --------------------------------------------------------------------

        _tf_section "Interpretation"


        if rg -q \
            "<PackageReference[^>]+Include=\"$thing\"" \
            -g '*.csproj' \
            . 2>/dev/null
        then
            _tf_found "NuGet PackageReference"
        fi


        if rg -q \
            "<PackageVersion[^>]+Include=\"$thing\"" \
            -g '*.props' \
            . 2>/dev/null
        then
            _tf_found "central NuGet package version"
        fi


        if rg -q \
            "<ProjectReference[^>]+$thing" \
            -g '*.csproj' \
            . 2>/dev/null
        then
            _tf_found "MSBuild project dependency"
        fi


        if rg -q \
            "<$thing([ >])" \
            -g '*.xml' \
            -g '*.config' \
            -g '*.csproj' \
            -g '*.props' \
            -g '*.targets' \
            -g '*.xsd' \
            -g '*.wsdl' \
            . 2>/dev/null
        then
            _tf_found "XML element"
        fi


        if rg -q \
            "[[:space:]]$thing=" \
            -g '*.xml' \
            -g '*.config' \
            -g '*.csproj' \
            -g '*.props' \
            -g '*.targets' \
            -g '*.xsd' \
            -g '*.wsdl' \
            . 2>/dev/null
        then
            _tf_found "XML attribute"
        fi


        case "$thing" in

            TargetFramework|TargetFrameworks)
                _tf_tech ".NET target framework configuration"
                ;;

            PackageReference)
                _tf_tech "NuGet dependency declaration"
                ;;

            PackageVersion)
                _tf_tech "central NuGet version declaration"
                ;;

            ProjectReference)
                _tf_tech ".NET project dependency"
                ;;

            PropertyGroup)
                _tf_tech "MSBuild property group"
                ;;

            ItemGroup)
                _tf_tech "MSBuild item group"
                ;;

            Target)
                _tf_tech "MSBuild build target"
                ;;

            Import)
                _tf_tech "MSBuild imported build logic"
                ;;

            connectionStrings)
                _tf_database "legacy .NET connection strings"
                ;;

            appSettings)
                _tf_tech "legacy .NET appSettings"
                ;;

        esac

        ;;


    # ========================================================================
    # RAW
    # ========================================================================

    raw|pretty)

        _tfx_require_xmlstarlet || return

        local file="$1"

        [[ -z "$file" ]] && {
            echo "Usage: tfx raw <file>"
            return 1
        }


        xmlstarlet fo \
            "$file"

        ;;


    # ========================================================================
    # TOOLS
    # ========================================================================

    tools)

        _tf_title "TFX TOOLING"

        _tf_section "Required"

        _tf_tool_status rg "ripgrep"
        _tf_tool_status fd "fd"


        _tf_section "XML"

        _tf_tool_status xmlstarlet "XMLStarlet"
        _tf_tool_status yq "yq"


        printf '\n'
        printf '  %sRecommended:%s\n' \
            "$TF_BOLD" \
            "$TF_RESET"

        printf '    %sXMLStarlet%s  XPath, validation, formatting, element inspection\n' \
            "$TF_BMAGENTA" \
            "$TF_RESET"

        printf '    %syq%s           XML -> YAML/JSON for easier human inspection\n' \
            "$TF_BMAGENTA" \
            "$TF_RESET"

        ;;


    # ========================================================================
    # HELP
    # ========================================================================

    help|-h|--help)

        cat <<'EOF'

tfx - smart XML project archaeology

GENERAL

  tfx
      Project-wide XML summary.

  tfx map
      Classify and structurally inspect every XML-like file.

  tfx file FILE
      Smart summary of one XML file.


.NET / MSBUILD

  tfx msbuild
      Understand .csproj, .props, .targets and central packages.


STRUCTURE

  tfx tree FILE
      Unique element hierarchy.

  tfx attrs FILE
      Attribute names and values.

  tfx values FILE
      Leaf elements and their values.

  tfx namespaces FILE
      Namespace prefixes and URIs.


RELATIONSHIPS

  tfx refs
      ProjectReference, Import, URL, file and schema references.

  tfx schemas
      XSDs, schema references and namespace declarations.

  tfx why THING
      Find a thing and explain known XML/MSBuild semantics.


QUERY

  tfx xpath FILE 'XPATH'
      Execute an XPath query.

  Example:

      tfx xpath Foo.csproj \
        '//*[local-name()="PackageReference"]/@Include'


VALIDATION / VIEWING

  tfx validate
      Validate all XML-like files for well-formedness.

  tfx raw FILE
      Pretty-print XML.

  tfx convert FILE
      Convert XML to YAML using yq.


TOOLS

  tfx tools
      Show installed/recommended XML tooling.


SUPPORTED FILE TYPES

  .xml
  .config
  .csproj
  .props
  .targets
  .xsd
  .wsdl
  .resx
  .nuspec


DESIGN

  tfx is read-only.

  XMLStarlet performs structural XML parsing.
  ripgrep is used for repository-wide evidence discovery.
  yq is optional and used only for alternate representations.

EOF

        ;;


    # ========================================================================
    # UNKNOWN
    # ========================================================================

    *)

        # Convenience:
        #
        #     tfx Foo.csproj
        #
        # behaves like:
        #
        #     tfx file Foo.csproj

        if [[ -f "$cmd" ]] && _tfx_is_xml_file "$cmd"; then

            tfx file "$cmd"

        else

            echo "tfx: unknown command or file: $cmd"
            echo "Run: tfx help"

            return 1

        fi

        ;;

    esac
}
# ============================================================================
# TFHOW - HOW TF DO I RUN THIS?
# ============================================================================
#
# Deterministic startup archaeology.
#
# Usage:
#   tfhow
#   tfhow startup
#   tfhow blockers
#   tfhow config
#   tfhow infra
#   tfhow db
#   tfhow migrations
#   tfhow docker
#   tfhow secrets
#   tfhow ports
#   tfhow env
#   tfhow order
#   tfhow evidence
#   tfhow why THING
#
# READ ONLY:
#   - does NOT run the application
#   - does NOT start Docker
#   - does NOT apply migrations
#   - does NOT modify configuration
#   - does NOT contact databases/services
#
# ============================================================================


# ----------------------------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------------------------
# ============================================================================
# MULTI-PROJECT / SCOPE HELPERS
# ============================================================================

_tfhow_project_name() {
    basename "$1" .csproj
}


_tfhow_project_dir() {
    dirname "$1"
}


_tfhow_is_test_project() {
    local project="$1"

    [[ "$project" == *Tests.csproj ||
       "$project" == *Test.csproj ||
       "$project" == */tests/* ||
       "$project" == */test/* ]] && return 0

    _tfhow_rg -q \
        '<IsTestProject>[[:space:]]*true[[:space:]]*</IsTestProject>|Microsoft\.NET\.Test\.Sdk|xunit|NUnit|MSTest' \
        "$project" 2>/dev/null
}


_tfhow_is_apphost() {
    local project="$1"

    [[ "$project" == *AppHost*.csproj ]] && return 0

    _tfhow_rg -q \
        'Aspire\.Hosting\.AppHost|DistributedApplication\.CreateBuilder' \
        "$project" "$(dirname "$project")" \
        2>/dev/null
}


_tfhow_is_web_project() {
    local project="$1"

    _tfhow_rg -q \
        '<Project[[:space:]][^>]*Sdk="Microsoft\.NET\.Sdk\.Web"' \
        "$project" 2>/dev/null
}


_tfhow_is_executable_project() {
    local project="$1"
    local dir=""

    dir="$(dirname "$project")"

    _tfhow_is_test_project "$project" && return 1

    _tfhow_is_apphost "$project" && return 0

    _tfhow_is_web_project "$project" && return 0

    _tfhow_rg -q \
        '<OutputType>[[:space:]]*(Exe|WinExe)[[:space:]]*</OutputType>' \
        "$project" 2>/dev/null &&
        return 0

    [[ -f "$dir/Program.cs" ]] && return 0

    return 1
}


_tfhow_project_role() {
    local project="$1"

    if _tfhow_is_test_project "$project"; then
        printf 'TEST'
    elif _tfhow_is_apphost "$project"; then
        printf 'ORCHESTRATOR'
    elif _tfhow_is_web_project "$project"; then
        printf 'WEB'
    elif _tfhow_is_executable_project "$project"; then
        printf 'EXECUTABLE'
    else
        printf 'LIBRARY'
    fi
}


_tfhow_runnable_projects() {
    local project=""

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        if _tfhow_is_executable_project "$project"; then
            printf '%s\n' "$project"
        fi

    done < <(_tfhow_csprojects)
}


_tfhow_library_projects() {
    local project=""

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        if ! _tfhow_is_executable_project "$project" &&
           ! _tfhow_is_test_project "$project"
        then
            printf '%s\n' "$project"
        fi

    done < <(_tfhow_csprojects)
}


_tfhow_test_projects() {
    local project=""

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        if _tfhow_is_test_project "$project"; then
            printf '%s\n' "$project"
        fi

    done < <(_tfhow_csprojects)
}


_tfhow_apphosts() {
    local project=""

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        if _tfhow_is_apphost "$project"; then
            printf '%s\n' "$project"
        fi

    done < <(_tfhow_csprojects)
}


_tfhow_resolve_project() {
    local query="$1"
    local project=""
    local matches=()

    [[ -z "$query" ]] && return 1

    # Exact path
    if [[ -f "$query" && "$query" == *.csproj ]]; then
        printf '%s\n' "$query"
        return 0
    fi

    # ./relative/path
    if [[ -f "./$query" && "$query" == *.csproj ]]; then
        printf '%s\n' "./$query"
        return 0
    fi

    # Search by project name/path
    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        local name=""
        name="$(_tfhow_project_name "$project")"

        if [[ "${name:l}" == "${query:l}" ||
              "${project:l}" == *"${query:l}"* ]]
        then
            matches+=("$project")
        fi

    done < <(_tfhow_csprojects)

    if (( ${#matches[@]} == 1 )); then
        printf '%s\n' "${matches[1]}"
        return 0
    fi

    if (( ${#matches[@]} > 1 )); then
        printf 'AMBIGUOUS\n'

        for project in "${matches[@]}"; do
            printf '%s\n' "$project"
        done

        return 2
    fi

    return 1
}


_tfhow_scope_rg() {
    local project="$1"
    shift

    local dir=""
    dir="$(_tfhow_project_dir "$project")"

    rg \
        --glob '!**/bin/**' \
        --glob '!**/obj/**' \
        --glob '!**/node_modules/**' \
        --glob '!**/.git/**' \
        "$@" \
        "$dir"
}


_tfhow_project_connection_keys() {
    local project="$1"

    {
        _tfhow_scope_rg "$project" \
            -o \
            'GetConnectionString\("[^"]+"' \
            -g '*.cs' \
            2>/dev/null |
        sed \
            's/.*GetConnectionString("//; s/"$//'

        _tfhow_scope_rg "$project" \
            -o \
            'Add(Npgsql|SqlServer|Sqlite)DbContext<[^>]+>\("[^"]+"' \
            -g '*.cs' \
            2>/dev/null |
        sed \
            's/.*>("//; s/"$//'

    } |
        sort -u
}


_tfhow_project_migration_count() {
    local project="$1"
    local dir=""

    dir="$(_tfhow_project_dir "$project")"

    fd \
        -e cs \
        . \
        "$dir" \
        --exclude bin \
        --exclude obj \
        2>/dev/null |
    rg '/Migrations/.*\.cs$' |
    rg -v '\.Designer\.cs$|ModelSnapshot\.cs$' |
    wc -l |
    tr -d ' '
}


_tfhow_project_has_auto_migrate() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        '\.Database\.Migrate(Async)?[[:space:]]*\(|MigrateDatabase|MigrateAsync[[:space:]]*\(' \
        -g '*.cs' \
        2>/dev/null
}


_tfhow_project_has_ensure_created() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        '\.Database\.EnsureCreated(Async)?[[:space:]]*\(' \
        -g '*.cs' \
        2>/dev/null
}


_tfhow_project_has_redis() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        'StackExchange\.Redis|AddRedis|AddStackExchangeRedis|AddRedisDistributedCache|AddRedisClient' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
}


_tfhow_project_has_rabbit() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        'RabbitMQ|UsingRabbitMq|AddRabbitMQ|AddRabbitMq' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
}


_tfhow_project_has_kafka() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        'Confluent\.Kafka|AddKafka|UsingKafka' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
}


_tfhow_project_has_grpc() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        'AddGrpc|MapGrpcService|Grpc\.' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
}


_tfhow_project_has_auth() {
    local project="$1"

    _tfhow_scope_rg "$project" \
        -q \
        'AddAuthentication|AddAuthorization|IdentityServer|AddIdentity|AddMicrosoftIdentity' \
        -g '*.cs' \
        2>/dev/null
}


_tfhow_project_provider() {
    local project="$1"

    if _tfhow_scope_rg "$project" \
        -q \
        'UseNpgsql|AddNpgsqlDbContext|Npgsql.EntityFrameworkCore' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
    then
        printf 'PostgreSQL'
        return
    fi

    if _tfhow_scope_rg "$project" \
        -q \
        'UseSqlServer|AddSqlServerDbContext|Microsoft.EntityFrameworkCore.SqlServer' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
    then
        printf 'SQL Server'
        return
    fi

    if _tfhow_scope_rg "$project" \
        -q \
        'UseSqlite|AddSqliteDbContext|Microsoft.EntityFrameworkCore.Sqlite' \
        -g '*.cs' \
        -g '*.csproj' \
        2>/dev/null
    then
        printf 'SQLite'
        return
    fi

    printf 'none detected'
}


_tfhow_project_launchsettings() {
    local project="$1"
    local dir=""

    dir="$(_tfhow_project_dir "$project")"

    if [[ -f "$dir/Properties/launchSettings.json" ]]; then
        printf '%s\n' "$dir/Properties/launchSettings.json"
    fi
}


_tfhow_project_urls() {
    local project="$1"
    local launch=""

    launch="$(_tfhow_project_launchsettings "$project")"

    [[ -z "$launch" ]] && return

    if command -v jq >/dev/null 2>&1; then
        jq -r \
            '.profiles // {} |
             to_entries[] |
             select(.value.applicationUrl != null) |
             .value.applicationUrl' \
            "$launch" \
            2>/dev/null
    else
        rg \
            -o \
            'https?://[^"; ]+' \
            "$launch" \
            2>/dev/null |
        sort -u
    fi
}


_tfhow_project_refs() {
    local project="$1"
    local basedir=""

    basedir="$(dirname "$project")"

    # Extract Include paths. We intentionally don't resolve/canonicalize them
    # here because displaying the declared dependency is useful evidence.
    sed -n \
        's/.*<ProjectReference[^>]*Include="\([^"]*\)".*/\1/p' \
        "$project" \
        2>/dev/null
}


_tfhow_reverse_refs() {
    local target="$1"
    local target_name=""
    local project=""

    target_name="$(basename "$target")"

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        if rg -q \
            "<ProjectReference[^>]*Include=\"[^\"]*${target_name}\"" \
            "$project" \
            2>/dev/null
        then
            printf '%s\n' "$project"
        fi

    done < <(_tfhow_csprojects)
}


_tfhow_apphost_children() {
    local apphost="$1"
    local dir=""

    dir="$(_tfhow_project_dir "$apphost")"

    # Aspire generated extension calls generally look like:
    # builder.AddProject<Projects.Some_Project>("name")
    #
    # This provides orchestration evidence even when mapping generated
    # Projects.* symbols back to csproj paths is imperfect.
    _tfhow_scope_rg "$apphost" \
        -o \
        'AddProject<Projects\.[A-Za-z0-9_]+' \
        -g '*.cs' \
        2>/dev/null |
    sed \
        's/.*AddProject<Projects\.//' |
    sort -u
}


_tfhow_print_project_summary() {
    local project="$1"

    local name=""
    local role=""
    local framework=""
    local provider=""
    local migrations=0
    local keys=""
    local urls=""

    name="$(_tfhow_project_name "$project")"
    role="$(_tfhow_project_role "$project")"
    framework="$(_tfhow_framework "$project")"
    provider="$(_tfhow_project_provider "$project")"
    migrations="$(_tfhow_project_migration_count "$project")"
    keys="$(_tfhow_project_connection_keys "$project")"
    urls="$(_tfhow_project_urls "$project")"

    _tfhow_header "$name"

    _tf_label "project"
    _tf_pathval "$project"

    _tf_label "role"
    _tf_value "$role"

    [[ -n "$framework" ]] && {
        _tf_label "framework"
        _tf_value "$framework"
    }

    if [[ "$role" != "LIBRARY" && "$role" != "TEST" ]]; then
        _tf_label "run"
        _tf_cfgval "dotnet run --project $project"
    fi

    if [[ "$provider" != "none detected" ]]; then
        _tf_label "database"
        _tf_dbval "$provider"
    fi

    if (( migrations > 0 )); then
        _tf_label "migrations"
        _tf_value "$migrations"

        if _tfhow_project_has_auto_migrate "$project"; then
            _tf_sub "schema" "startup migration detected"
        elif _tfhow_project_has_ensure_created "$project"; then
            _tf_sub "schema" "EnsureCreated detected"
        else
            _tf_sub "schema" "appears externally prepared"
        fi
    fi

    if [[ -n "$keys" ]]; then
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            _tf_sub "connection" "$key"
        done <<< "$keys"
    fi

    _tfhow_project_has_redis "$project" &&
        _tf_sub "requires?" "Redis"

    _tfhow_project_has_rabbit "$project" &&
        _tf_sub "requires?" "RabbitMQ"

    _tfhow_project_has_kafka "$project" &&
        _tf_sub "requires?" "Kafka"

    _tfhow_project_has_grpc "$project" &&
        _tf_sub "uses" "gRPC"

    _tfhow_project_has_auth "$project" &&
        _tf_sub "uses" "authentication / authorization"

    if [[ -n "$urls" ]]; then
        while IFS= read -r url; do
            [[ -z "$url" ]] && continue
            _tf_sub "URL" "$url"
        done <<< "$urls"
    fi
}


_tfhow_project_blockers() {
    local project="$1"

    local migrations=0
    local keys=""
    local count=0

    migrations="$(_tfhow_project_migration_count "$project")"
    keys="$(_tfhow_project_connection_keys "$project")"

    _tfhow_header "$(_tfhow_project_name "$project")"

    if [[ -n "$keys" ]]; then
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue

            if ! _tfhow_config_key_exists "$key" &&
               ! _tfhow_env_key_exists "$key"
            then
                _tfhow_medium \
                    "connection '$key' is not present in tracked configuration"
                (( count++ ))
            fi
        done <<< "$keys"
    fi

    if (( migrations > 0 )) &&
       ! _tfhow_project_has_auto_migrate "$project" &&
       ! _tfhow_project_has_ensure_created "$project"
    then
        _tfhow_medium \
            "$migrations migrations exist; this project does not appear to apply them"
        (( count++ ))
    fi

    if _tfhow_project_has_redis "$project"; then
        _tfhow_low "Redis dependency should be verified"
        (( count++ ))
    fi

    if _tfhow_project_has_rabbit "$project"; then
        _tfhow_low "RabbitMQ dependency should be verified"
        (( count++ ))
    fi

    if _tfhow_project_has_kafka "$project"; then
        _tfhow_low "Kafka dependency should be verified"
        (( count++ ))
    fi

    (( count == 0 )) &&
        _tfhow_fact "No obvious static blockers"
}


_tfhow_project_order() {
    local project="$1"

    local step=1
    local keys=""
    local migrations=0

    keys="$(_tfhow_project_connection_keys "$project")"
    migrations="$(_tfhow_project_migration_count "$project")"

    _tfhow_header "$(_tfhow_project_name "$project")"

    if _tfhow_project_has_redis "$project" ||
       _tfhow_project_has_rabbit "$project" ||
       _tfhow_project_has_kafka "$project"
    then
        _tfhow_step "$step" "Verify/start required infrastructure"

        _tfhow_project_has_redis "$project" &&
            _tf_sub "service" "Redis"

        _tfhow_project_has_rabbit "$project" &&
            _tf_sub "service" "RabbitMQ"

        _tfhow_project_has_kafka "$project" &&
            _tf_sub "service" "Kafka"

        (( step++ ))
    fi

    if [[ -n "$keys" ]]; then
        _tfhow_step "$step" "Resolve required connection strings"

        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            _tf_sub "connection" "$key"
        done <<< "$keys"

        (( step++ ))
    fi

    if (( migrations > 0 )); then
        _tfhow_step "$step" "Verify database schema state"

        if _tfhow_project_has_auto_migrate "$project"; then
            _tf_sub "behavior" "startup migration detected"
        elif _tfhow_project_has_ensure_created "$project"; then
            _tf_sub "behavior" "EnsureCreated detected"
        else
            _tf_sub "behavior" "schema appears externally prepared"
            _tf_sub "warning" "do not blindly apply migrations"
        fi

        (( step++ ))
    fi

    _tfhow_step "$step" "Run project"

    _tf_sub "command" \
        "dotnet run --project $project"
}
_tfhow_files() {
    fd -t f \
        --exclude bin \
        --exclude obj \
        --exclude node_modules \
        --exclude .git \
        . 2>/dev/null
}


_tfhow_rg() {
    rg \
        --glob '!**/bin/**' \
        --glob '!**/obj/**' \
        --glob '!**/node_modules/**' \
        --glob '!**/.git/**' \
        "$@"
}


_tfhow_first() {
    _tfhow_rg "$@" 2>/dev/null | head -1
}


_tfhow_count_files() {
    _tfhow_rg -l "$@" . 2>/dev/null |
        wc -l |
        tr -d ' '
}


_tfhow_count_matches() {
    _tfhow_rg "$@" . 2>/dev/null |
        wc -l |
        tr -d ' '
}


_tfhow_yesno() {
    if (( $1 > 0 )); then
        printf '%sYES%s' "$TF_BGREEN" "$TF_RESET"
    else
        printf '%sNO%s' "$TF_DIM" "$TF_RESET"
    fi
}


_tfhow_header() {
    printf '\n  %s%s%s%s\n' \
        "$TF_BOLD" "$TF_BMAGENTA" "$1" "$TF_RESET"
}


_tfhow_high() {
    printf '  %sHIGH%s    %s\n' \
        "$TF_BRED" "$TF_RESET" "$1"
}


_tfhow_medium() {
    printf '  %sMEDIUM%s  %s\n' \
        "$TF_BYELLOW" "$TF_RESET" "$1"
}


_tfhow_low() {
    printf '  %sLOW%s     %s\n' \
        "$TF_BBLUE" "$TF_RESET" "$1"
}


_tfhow_fact() {
    printf '  %s✓%s %s\n' \
        "$TF_BGREEN" "$TF_RESET" "$1"
}


_tfhow_question() {
    printf '  %s?%s %s\n' \
        "$TF_BYELLOW" "$TF_RESET" "$1"
}


_tfhow_step() {
    local n="$1"
    shift

    printf '  %s%s%s. %s\n' \
        "$TF_BCYAN" "$n" "$TF_RESET" "$*"
}


_tfhow_path_exists() {
    [[ -e "$1" ]]
}


_tfhow_csprojects() {
    fd -e csproj \
        --exclude bin \
        --exclude obj \
        . 2>/dev/null
}


_tfhow_startup_candidates() {
    local file=""

    while IFS= read -r file; do

        [[ -z "$file" ]] && continue

        local score=0
        local reason=""

        if [[ -f "$(dirname "$file")/Program.cs" ]]; then
            (( score += 5 ))
            reason+="Program.cs "
        fi

        if _tfhow_rg -q \
            '<Project[[:space:]][^>]*Sdk="Microsoft\.NET\.Sdk\.Web"' \
            "$file" 2>/dev/null
        then
            (( score += 5 ))
            reason+="WebSDK "
        fi

        if _tfhow_rg -q \
            '<OutputType>[[:space:]]*Exe[[:space:]]*</OutputType>' \
            "$file" 2>/dev/null
        then
            (( score += 3 ))
            reason+="Exe "
        fi

        if _tfhow_rg -q \
            'Microsoft\.Extensions\.Hosting|AspNetCore' \
            "$file" 2>/dev/null
        then
            (( score += 2 ))
            reason+="Host "
        fi

        case "$file" in
            *AppHost*.csproj)
                (( score += 10 ))
                reason+="AspireAppHost "
                ;;
        esac

        if (( score > 0 )); then
            printf '%s|%s|%s\n' "$score" "$file" "$reason"
        fi

    done < <(_tfhow_csprojects) |
        sort -t'|' -k1,1nr
}


_tfhow_primary_startup() {
    _tfhow_startup_candidates |
        head -1 |
        cut -d'|' -f2
}


_tfhow_framework() {
    local project="$1"

    [[ -z "$project" ]] && return

    local framework=""

    framework="$(
        sed -n \
            's:.*<TargetFramework>\([^<]*\)</TargetFramework>.*:\1:p' \
            "$project" |
        head -1
    )"

    if [[ -z "$framework" ]]; then
        framework="$(
            sed -n \
                's:.*<TargetFrameworks>\([^<]*\)</TargetFrameworks>.*:\1:p' \
                "$project" |
            head -1
        )"
    fi

    printf '%s' "$framework"
}


_tfhow_project_type() {
    local project="$1"

    if [[ "$project" == *AppHost*.csproj ]]; then
        printf 'Aspire AppHost'
        return
    fi

    if _tfhow_rg -q \
        '<Project[[:space:]][^>]*Sdk="Microsoft\.NET\.Sdk\.Web"' \
        "$project" 2>/dev/null
    then
        printf 'ASP.NET Core'
        return
    fi

    if _tfhow_rg -q \
        '<OutputType>[[:space:]]*Exe[[:space:]]*</OutputType>' \
        "$project" 2>/dev/null
    then
        printf 'Console / executable'
        return
    fi

    printf '.NET project'
}


_tfhow_appsettings() {
    fd \
        '^appsettings(\..+)?\.json$' \
        --exclude bin \
        --exclude obj \
        . 2>/dev/null |
        sort
}


_tfhow_launchsettings() {
    fd \
        '^launchSettings\.json$' \
        --exclude bin \
        --exclude obj \
        . 2>/dev/null
}


_tfhow_compose_files() {
    fd \
        '^(docker-compose|compose)(\.[^.]+)?\.(yml|yaml)$' \
        --exclude bin \
        --exclude obj \
        . 2>/dev/null
}


_tfhow_dockerfiles() {
    fd \
        '^(Dockerfile|Containerfile)(\..*)?$' \
        --exclude bin \
        --exclude obj \
        . 2>/dev/null
}


_tfhow_connection_keys() {

    {
        _tfhow_rg -o \
            'GetConnectionString\("[^"]+"' \
            -g '*.cs' \
            . 2>/dev/null |
        sed \
            's/.*GetConnectionString("//; s/"$//'

        _tfhow_rg -o \
            'Add(Npgsql|SqlServer|Sqlite)DbContext<[^>]+>\("[^"]+"' \
            -g '*.cs' \
            . 2>/dev/null |
        sed \
            's/.*>("//; s/"$//'

        _tfhow_rg -o \
            'ConnectionStrings__[A-Za-z0-9_.:-]+' \
            -g '*.yml' \
            -g '*.yaml' \
            -g '*.env' \
            -g '*.json' \
            . 2>/dev/null |
        sed 's/.*ConnectionStrings__//'

    } |
        sort -u
}


_tfhow_config_key_exists() {
    local key="$1"

    _tfhow_rg -q \
        "\"${key}\"[[:space:]]*:" \
        -g 'appsettings*.json' \
        . 2>/dev/null
}


_tfhow_env_key_exists() {
    local key="$1"

    _tfhow_rg -q \
        "ConnectionStrings__${key}|${key}=" \
        -g '*.env' \
        -g '*.yml' \
        -g '*.yaml' \
        . 2>/dev/null
}


_tfhow_has_user_secrets() {
    _tfhow_rg -q \
        '<UserSecretsId>[^<]+' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_migration_count() {
    fd \
        -e cs \
        . \
        --exclude bin \
        --exclude obj \
        2>/dev/null |
    rg '/Migrations/.*\.cs$' |
    rg -v '\.Designer\.cs$|ModelSnapshot\.cs$' |
    wc -l |
    tr -d ' '
}


_tfhow_context_count() {
    _tfhow_rg -l \
        'class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*.*:[[:space:]].*(DbContext|IdentityDbContext)' \
        -g '*.cs' \
        . 2>/dev/null |
    wc -l |
    tr -d ' '
}


_tfhow_has_auto_migrate() {
    _tfhow_rg -q \
        '\.Database\.Migrate(Async)?[[:space:]]*\(|MigrateDatabase|MigrateAsync[[:space:]]*\(' \
        -g '*.cs' \
        . 2>/dev/null
}


_tfhow_has_ensure_created() {
    _tfhow_rg -q \
        '\.Database\.EnsureCreated(Async)?[[:space:]]*\(' \
        -g '*.cs' \
        . 2>/dev/null
}


_tfhow_has_ensure_deleted() {
    _tfhow_rg -q \
        '\.Database\.EnsureDeleted(Async)?[[:space:]]*\(' \
        -g '*.cs' \
        . 2>/dev/null
}


_tfhow_detect_provider() {

    if _tfhow_rg -q \
        'UseNpgsql|AddNpgsqlDbContext|Npgsql.EntityFrameworkCore' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
    then
        printf 'PostgreSQL'
        return
    fi

    if _tfhow_rg -q \
        'UseSqlServer|AddSqlServerDbContext|Microsoft.EntityFrameworkCore.SqlServer' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
    then
        printf 'SQL Server'
        return
    fi

    if _tfhow_rg -q \
        'UseSqlite|AddSqliteDbContext|Microsoft.EntityFrameworkCore.Sqlite' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
    then
        printf 'SQLite'
        return
    fi

    if _tfhow_rg -q \
        'Pomelo.EntityFrameworkCore.MySql|UseMySql' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
    then
        printf 'MySQL/MariaDB'
        return
    fi

    printf 'unknown'
}


_tfhow_has_redis() {
    _tfhow_rg -q \
        'StackExchange\.Redis|AddRedis|AddStackExchangeRedis|AddRedisDistributedCache|AddRedisClient' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_has_rabbit() {
    _tfhow_rg -q \
        'RabbitMQ|UsingRabbitMq|AddRabbitMQ|AddRabbitMq' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_has_kafka() {
    _tfhow_rg -q \
        'Confluent\.Kafka|AddKafka|UsingKafka' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_has_mongo() {
    _tfhow_rg -q \
        'MongoDB\.Driver|MongoClient' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_has_grpc() {
    _tfhow_rg -q \
        'AddGrpc|MapGrpcService|Grpc\.' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_has_auth() {
    _tfhow_rg -q \
        'AddAuthentication|AddAuthorization|IdentityServer|AddIdentity|AddMicrosoftIdentity' \
        -g '*.cs' \
        . 2>/dev/null
}


_tfhow_has_aspire() {
    _tfhow_rg -q \
        'Aspire\.Hosting|DistributedApplication\.CreateBuilder|AddProject<' \
        -g '*.cs' \
        -g '*.csproj' \
        . 2>/dev/null
}


_tfhow_has_https() {
    _tfhow_rg -q \
        'https://localhost|applicationUrl.*https|UseHttpsRedirection' \
        -g '*.json' \
        -g '*.cs' \
        . 2>/dev/null
}


_tfhow_has_cert_refs() {
    _tfhow_rg -q \
        'Certificate|Certificates|Kestrel.*Https|\.pfx|\.pem|\.crt' \
        -g '*.json' \
        -g '*.cs' \
        -g '*.yml' \
        -g '*.yaml' \
        . 2>/dev/null
}


_tfhow_package_manager() {

    [[ -f pnpm-lock.yaml ]] && {
        printf 'pnpm'
        return
    }

    [[ -f yarn.lock ]] && {
        printf 'yarn'
        return
    }

    [[ -f bun.lockb || -f bun.lock ]] && {
        printf 'bun'
        return
    }

    [[ -f package-lock.json ]] && {
        printf 'npm'
        return
    }

    if fd \
        '^pnpm-lock\.yaml$' \
        --exclude node_modules \
        . 2>/dev/null |
        grep -q .
    then
        printf 'pnpm'
        return
    fi

    if fd \
        '^yarn\.lock$' \
        --exclude node_modules \
        . 2>/dev/null |
        grep -q .
    then
        printf 'yarn'
        return
    fi

    if fd \
        '^package-lock\.json$' \
        --exclude node_modules \
        . 2>/dev/null |
        grep -q .
    then
        printf 'npm'
        return
    fi

    printf ''
}


_tfhow_has_frontend() {
    fd \
        '^package\.json$' \
        --exclude node_modules \
        . 2>/dev/null |
        grep -q .
}


_tfhow_readme_run_evidence() {

    _tfhow_rg -n \
        -i \
        '(dotnet run|docker compose|docker-compose|database update|dotnet ef|npm run|pnpm |yarn |bun |localhost|connection string|migration|user.?secrets)' \
        -g 'README*' \
        -g '*.md' \
        . 2>/dev/null |
    head -80
}


# ============================================================================
# MAIN
# ============================================================================

tfhow() {

    # Prevent zsh from printing redeclared local/typeset values.
    setopt localoptions typesetsilent 2>/dev/null

    local cmd="${1:-summary}"

    [[ $# -gt 0 ]] && shift

    _tf_need rg || return
    _tf_need fd || return


    case "$cmd" in


    # ========================================================================
    # SUMMARY
    # ========================================================================

    summary|overview|ov)

        _tf_title "HOW TF DO I RUN THIS?"

        local startup=""
        local framework=""
        local project_type=""
        local provider=""
        local migrations=0
        local contexts=0
        local compose_count=0
        local dockerfile_count=0
        local appsettings_count=0
        local launch_count=0

        startup="$(_tfhow_primary_startup)"

        [[ -n "$startup" ]] && {
            framework="$(_tfhow_framework "$startup")"
            project_type="$(_tfhow_project_type "$startup")"
        }

        provider="$(_tfhow_detect_provider)"

        migrations="$(_tfhow_migration_count)"
        contexts="$(_tfhow_context_count)"

        compose_count="$(
            _tfhow_compose_files |
            wc -l |
            tr -d ' '
        )"

        dockerfile_count="$(
            _tfhow_dockerfiles |
            wc -l |
            tr -d ' '
        )"

        appsettings_count="$(
            _tfhow_appsettings |
            wc -l |
            tr -d ' '
        )"

        launch_count="$(
            _tfhow_launchsettings |
            wc -l |
            tr -d ' '
        )"


        # --------------------------------------------------------------------
        # APPLICATION
        # --------------------------------------------------------------------

        _tf_section "Application"

        if [[ -n "$startup" ]]; then

            _tf_label "startup candidate"
            _tf_pathval "$startup"

            _tf_label "type"
            _tf_value "$project_type"

            [[ -n "$framework" ]] && {
                _tf_label "framework"
                _tf_value "$framework"
            }

            if _tfhow_has_aspire; then
                _tf_label "orchestration"
                _tf_cfgval ".NET Aspire detected"
            fi

        else

            _tf_warn "startup project" \
                "could not confidently identify one"

        fi


        # --------------------------------------------------------------------
        # CONFIGURATION
        # --------------------------------------------------------------------

        _tf_section "Configuration"

        _tf_label "appsettings"
        _tf_value "$appsettings_count"

        _tf_label "launch settings"
        _tf_value "$launch_count"

        if _tfhow_has_user_secrets; then
            _tf_label "user secrets"
            _tf_cfgval "configured"
        else
            _tf_label "user secrets"
            _tf_value "not detected"
        fi


        # --------------------------------------------------------------------
        # DATABASE
        # --------------------------------------------------------------------

        _tf_section "Database"

        _tf_label "provider"
        _tf_dbval "$provider"

        _tf_label "DbContexts"
        _tf_value "$contexts"

        _tf_label "migrations"
        _tf_value "$migrations"


        if _tfhow_has_auto_migrate; then

            _tf_label "startup migration"
            _tf_cfgval "Database.Migrate() detected"

        else

            _tf_label "startup migration"
            _tf_value "none detected"

        fi


        if _tfhow_has_ensure_created; then

            _tf_warn "EnsureCreated" \
                "application may create schema itself"

        fi


        if _tfhow_has_ensure_deleted; then

            _tf_bad "EnsureDeleted" \
                "database deletion code exists"

        fi


        local keys=""
        keys="$(_tfhow_connection_keys)"


        if [[ -n "$keys" ]]; then

            printf '\n'

            while IFS= read -r key; do

                [[ -z "$key" ]] && continue

                _tf_label "connection"
                _tf_cfgval "$key"

            done <<< "$keys"

        fi


        # --------------------------------------------------------------------
        # INFRASTRUCTURE
        # --------------------------------------------------------------------

        _tf_section "Infrastructure"

        (( compose_count > 0 )) && {
            _tf_label "Compose files"
            _tf_value "$compose_count"
        }

        (( dockerfile_count > 0 )) && {
            _tf_label "Dockerfiles"
            _tf_value "$dockerfile_count"
        }


        _tfhow_has_redis &&
            _tf_database "Redis"

        _tfhow_has_rabbit &&
            _tf_messaging "RabbitMQ"

        _tfhow_has_kafka &&
            _tf_messaging "Kafka"

        _tfhow_has_mongo &&
            _tf_database "MongoDB"

        _tfhow_has_grpc &&
            _tf_tech "gRPC"

        _tfhow_has_auth &&
            _tf_tech "authentication / authorization"


        # --------------------------------------------------------------------
        # FIRST-RUN RISKS
        # --------------------------------------------------------------------

        _tf_section "First-Run Risks"

        local risk_count=0


        if (( migrations > 0 )) &&
           ! _tfhow_has_auto_migrate &&
           ! _tfhow_has_ensure_created
        then

            _tfhow_medium \
                "$migrations EF migrations exist but startup does not appear to apply them"

            (( risk_count++ ))

        fi


        if _tfhow_has_user_secrets; then

            _tfhow_low \
                "UserSecretsId exists; required values may live outside Git"

            (( risk_count++ ))

        fi


        if _tfhow_has_https; then

            _tfhow_low \
                "HTTPS detected; local development certificate may be required"

            (( risk_count++ ))

        fi


        if _tfhow_has_cert_refs; then

            _tfhow_medium \
                "certificate-related configuration detected"

            (( risk_count++ ))

        fi


        if [[ -n "$keys" ]]; then

            while IFS= read -r key; do

                [[ -z "$key" ]] && continue

                if ! _tfhow_config_key_exists "$key" &&
                   ! _tfhow_env_key_exists "$key"
                then

                    _tfhow_medium \
                        "connection '$key' is referenced but not found in tracked config"

                    (( risk_count++ ))

                fi

            done <<< "$keys"

        fi


        (( risk_count == 0 )) &&
            _tfhow_fact \
                "No obvious static startup blockers detected"


        # --------------------------------------------------------------------
        # LIKELY ORDER
        # --------------------------------------------------------------------

        _tf_section "Likely Startup Order"

        local step=1


        if (( compose_count > 0 )); then

            _tfhow_step "$step" \
                "Review/start required Compose infrastructure"

            (( step++ ))

        fi


        if [[ -n "$keys" ]]; then

            _tfhow_step "$step" \
                "Resolve required connection strings"

            (( step++ ))

        fi


        if (( migrations > 0 )); then

            _tfhow_step "$step" \
                "Verify database schema/migration state"

            (( step++ ))

        fi


        if _tfhow_has_frontend; then

            local pm=""
            pm="$(_tfhow_package_manager)"

            _tfhow_step "$step" \
                "Verify frontend dependencies${pm:+ ($pm)}"

            (( step++ ))

        fi


        if [[ -n "$startup" ]]; then

            _tfhow_step "$step" \
                "Run: dotnet run --project $startup"

        else

            _tfhow_step "$step" \
                "Determine the intended startup project"

        fi


        printf '\n'
        _tf_warn "READ ONLY" \
            "nothing was started, migrated, connected to, or modified"

        ;;


    # ========================================================================
    # STARTUP
    # ========================================================================

  
    startup|start)

        _tf_title "SOLUTION STARTUP MAP"

        local runnable=""
        local libraries=""
        local tests=""
        local apphosts=""

        runnable="$(_tfhow_runnable_projects)"
        libraries="$(_tfhow_library_projects)"
        tests="$(_tfhow_test_projects)"
        apphosts="$(_tfhow_apphosts)"

        _tf_section "Runnable Projects"

        if [[ -n "$runnable" ]]; then

            while IFS= read -r project; do
                [[ -z "$project" ]] && continue
                _tfhow_print_project_summary "$project"
            done <<< "$runnable"

        else
            _tf_warn "startup" "no runnable projects detected"
        fi


        if [[ -n "$apphosts" ]]; then

            _tf_section "Orchestration"

            while IFS= read -r apphost; do
                [[ -z "$apphost" ]] && continue

                _tfhow_header "$(_tfhow_project_name "$apphost")"

                _tf_label "role"
                _tf_cfgval "Aspire AppHost"

                _tf_label "run"
                _tf_cfgval "dotnet run --project $apphost"

                local children=""
                children="$(_tfhow_apphost_children "$apphost")"

                if [[ -n "$children" ]]; then
                    while IFS= read -r child; do
                        [[ -z "$child" ]] && continue
                        _tf_sub "orchestrates" "$child"
                    done <<< "$children"
                fi
            done <<< "$apphosts"
        fi


        _tf_section "Libraries"

        if [[ -n "$libraries" ]]; then
            while IFS= read -r project; do
                [[ -z "$project" ]] && continue

                _tf_label "$(_tfhow_project_name "$project")"
                _tf_pathval "$project"
            done <<< "$libraries"
        else
            _tf_dim "None detected."
        fi


        _tf_section "Tests"

        if [[ -n "$tests" ]]; then
            while IFS= read -r project; do
                [[ -z "$project" ]] && continue

                _tf_label "$(_tfhow_project_name "$project")"
                _tf_pathval "$project"
            done <<< "$tests"
        else
            _tf_dim "None detected."
        fi


        _tf_section "Project Relationships"

        local project=""

        while IFS= read -r project; do
            [[ -z "$project" ]] && continue

            local refs=""
            refs="$(_tfhow_project_refs "$project")"

            [[ -z "$refs" ]] && continue

            _tfhow_header "$(_tfhow_project_name "$project")"

            while IFS= read -r ref; do
                [[ -z "$ref" ]] && continue
                _tf_sub "references" "$ref"
            done <<< "$refs"

        done < <(_tfhow_csprojects)


        local runnable_count=0

        runnable_count="$(
            printf '%s\n' "$runnable" |
            sed '/^$/d' |
            wc -l |
            tr -d ' '
        )"

        _tf_section "Conclusion"

        if [[ -n "$apphosts" ]]; then

            _tfhow_fact \
                "Aspire AppHost detected; it is the likely orchestration entry point"

        elif (( runnable_count == 1 )); then

            _tfhow_fact \
                "one runnable project detected"

        elif (( runnable_count > 1 )); then

            _tfhow_question \
                "$runnable_count runnable projects detected; no primary startup project assumed"

            _tf_dim \
                "Use: tfhow project <name>"

        else

            _tfhow_question \
                "no runnable startup project identified"

        fi

        ;;

    # ========================================================================
    # BLOCKERS
    # ========================================================================

    blockers|blocker)

        _tf_title "STARTUP BLOCKERS"

        local high=0
        local medium=0
        local low=0

        local startup=""
        local migrations=0
        local keys=""

        startup="$(_tfhow_primary_startup)"
        migrations="$(_tfhow_migration_count)"
        keys="$(_tfhow_connection_keys)"


        # --------------------------------------------------------------------
        # HIGH
        # --------------------------------------------------------------------

        _tf_section "High Confidence"

        if [[ -z "$startup" ]]; then

            _tfhow_high \
                "No startup project could be identified"

            (( high++ ))

        fi


        if [[ -n "$keys" ]]; then

            while IFS= read -r key; do

                [[ -z "$key" ]] && continue

                if ! _tfhow_config_key_exists "$key" &&
                   ! _tfhow_env_key_exists "$key" &&
                   ! _tfhow_has_user_secrets
                then

                    _tfhow_high \
                        "connection string '$key' appears unresolved"

                    (( high++ ))

                fi

            done <<< "$keys"

        fi


        (( high == 0 )) &&
            _tfhow_fact \
                "No high-confidence static blockers"


        # --------------------------------------------------------------------
        # MEDIUM
        # --------------------------------------------------------------------

        _tf_section "Needs Verification"

        if (( migrations > 0 )) &&
           ! _tfhow_has_auto_migrate &&
           ! _tfhow_has_ensure_created
        then

            _tfhow_medium \
                "$migrations migrations exist and no automatic migration call was found"

            (( medium++ ))

        fi


        if _tfhow_has_cert_refs; then

            _tfhow_medium \
                "certificate configuration exists; verify local certificate availability"

            (( medium++ ))

        fi


        if _tfhow_has_redis; then

            _tfhow_medium \
                "Redis is referenced; verify whether it must be running"

            (( medium++ ))

        fi


        if _tfhow_has_rabbit; then

            _tfhow_medium \
                "RabbitMQ is referenced; verify whether it must be running"

            (( medium++ ))

        fi


        if _tfhow_has_kafka; then

            _tfhow_medium \
                "Kafka is referenced; verify whether it must be running"

            (( medium++ ))

        fi


        (( medium == 0 )) &&
            _tfhow_fact \
                "No obvious medium-confidence blockers"


        # --------------------------------------------------------------------
        # LOW
        # --------------------------------------------------------------------

        _tf_section "External / Hidden State"

        if _tfhow_has_user_secrets; then

            _tfhow_low \
                "User Secrets are configured; Git cannot reveal their values"

            (( low++ ))

        fi


        if _tfhow_has_https; then

            _tfhow_low \
                "HTTPS development configuration detected"

            (( low++ ))

        fi


        if _tfhow_has_auth; then

            _tfhow_low \
                "authentication/authorization may depend on external identity configuration"

            (( low++ ))

        fi


        (( low == 0 )) &&
            _tfhow_fact \
                "No obvious hidden-state dependencies"


        _tf_section "Summary"

        _tf_label "high"
        _tf_value "$high"

        _tf_label "verify"
        _tf_value "$medium"

        _tf_label "external"
        _tf_value "$low"

        printf '\n'
        _tf_warn "Important" \
            "these are static findings, not runtime health checks"

        ;;


    # ========================================================================
    # CONFIG
    # ========================================================================

    config|configuration)

        _tf_title "STARTUP CONFIGURATION"

        _tf_section "Tracked Configuration Files"

        local files=""
        files="$(_tfhow_appsettings)"


        if [[ -n "$files" ]]; then

            while IFS= read -r file; do
                _tf_path "$file"
            done <<< "$files"

        else

            _tf_dim "No appsettings files found."

        fi


        _tf_section "Configuration Sources"

        if _tfhow_rg -q \
            'CreateDefaultBuilder|WebApplication\.CreateBuilder' \
            -g '*.cs' \
            . 2>/dev/null
        then
            _tfhow_fact \
                "default .NET configuration pipeline detected"

            printf '\n'
            _tf_sub "1." "appsettings.json"
            _tf_sub "2." "appsettings.{Environment}.json"
            _tf_sub "3." "User Secrets in Development, when configured"
            _tf_sub "4." "environment variables"
            _tf_sub "5." "command-line arguments"
        fi


        _tf_section "Explicit Configuration Extensions"

        local explicit=""

        explicit="$(
            _tfhow_rg -n \
                'AddJsonFile|AddEnvironmentVariables|AddCommandLine|AddUserSecrets|AddIniFile|AddXmlFile|Configure<|GetSection\(' \
                -g '*.cs' \
                . 2>/dev/null |
            head -100
        )"

        [[ -n "$explicit" ]] &&
            printf '%s\n' "$explicit" ||
            _tf_dim "No explicit additions detected."


        _tf_section "Connection Strings"

        local keys=""
        keys="$(_tfhow_connection_keys)"

        if [[ -n "$keys" ]]; then

            while IFS= read -r key; do

                [[ -z "$key" ]] && continue

                _tf_label "key"
                _tf_cfgval "$key"

                if _tfhow_config_key_exists "$key"; then

                    _tf_sub "tracked config" \
                        "found"

                elif _tfhow_env_key_exists "$key"; then

                    _tf_sub "environment" \
                        "reference found"

                elif _tfhow_has_user_secrets; then

                    _tf_sub "tracked config" \
                        "not found; may be in User Secrets"

                else

                    _tf_sub "tracked config" \
                        "NOT FOUND"

                fi

            done <<< "$keys"

        else

            _tf_dim "No GetConnectionString keys detected."

        fi


        _tf_section "Options / Sections"

        _tfhow_rg -o \
            'GetSection\("[^"]+"|Configuration\["[^"]+"|configuration\["[^"]+"' \
            -g '*.cs' \
            . 2>/dev/null |
        sed \
            -e 's/.*GetSection("//' \
            -e 's/.*\["//' \
            -e 's/"$//' |
        sort -u |
        head -100

        ;;


    # ========================================================================
    # INFRA
    # ========================================================================

    infra|infrastructure)

        _tf_title "REQUIRED INFRASTRUCTURE"

        local found=0
        local provider=""

        provider="$(_tfhow_detect_provider)"


        if [[ "$provider" != "unknown" ]]; then

            _tf_section "Database"

            _tf_database "$provider"

            (( found++ ))

        fi


        if _tfhow_has_redis; then

            _tf_section "Cache / Storage"
            _tf_database "Redis"

            (( found++ ))

        fi


        if _tfhow_has_mongo; then

            _tf_section "Document Database"
            _tf_database "MongoDB"

            (( found++ ))

        fi


        if _tfhow_has_rabbit; then

            _tf_section "Messaging"
            _tf_messaging "RabbitMQ"

            (( found++ ))

        fi


        if _tfhow_has_kafka; then

            _tf_section "Messaging"
            _tf_messaging "Kafka"

            (( found++ ))

        fi


        if _tfhow_has_grpc; then

            _tf_section "RPC"
            _tf_tech "gRPC"

            (( found++ ))

        fi


        if _tfhow_has_auth; then

            _tf_section "Identity"
            _tf_tech "Authentication / Authorization"

            (( found++ ))

        fi


        if _tfhow_has_aspire; then

            _tf_section "Orchestration"
            _tf_framework ".NET Aspire"

            (( found++ ))

        fi


        (( found == 0 )) &&
            _tf_dim \
                "No obvious infrastructure dependencies detected."


        _tf_section "Evidence"

        _tfhow_rg -n \
            'UseNpgsql|UseSqlServer|UseSqlite|AddNpgsqlDbContext|AddSqlServerDbContext|StackExchange.Redis|RabbitMQ|UsingRabbitMq|Confluent.Kafka|MongoClient|AddGrpc|AddAuthentication|AddAuthorization|AddMicrosoftIdentity' \
            -g '*.cs' \
            -g '*.csproj' \
            . 2>/dev/null |
        head -120

        ;;


    # ========================================================================
    # DB
    # ========================================================================

    db|database)

        _tf_title "DATABASE STARTUP REQUIREMENTS"

        local provider=""
        local migrations=0
        local contexts=0
        local keys=""

        provider="$(_tfhow_detect_provider)"
        migrations="$(_tfhow_migration_count)"
        contexts="$(_tfhow_context_count)"
        keys="$(_tfhow_connection_keys)"


        _tf_section "Database"

        _tf_label "provider"
        _tf_dbval "$provider"

        _tf_label "contexts"
        _tf_value "$contexts"

        _tf_label "migrations"
        _tf_value "$migrations"


        _tf_section "Connection Requirements"

        if [[ -n "$keys" ]]; then

            while IFS= read -r key; do

                [[ -z "$key" ]] && continue

                _tfhow_header "$key"

                if _tfhow_config_key_exists "$key"; then

                    _tf_label "tracked config"
                    _tf_ok "status" "found"

                elif _tfhow_env_key_exists "$key"; then

                    _tf_label "environment"
                    _tf_ok "status" "reference found"

                elif _tfhow_has_user_secrets; then

                    _tf_label "resolution"
                    _tf_warn "status" \
                        "possibly User Secrets"

                else

                    _tf_label "resolution"
                    _tf_bad "status" \
                        "not found"

                fi

            done <<< "$keys"

        else

            _tf_dim "No named connection strings detected."

        fi


        _tf_section "Schema Initialization"

        if _tfhow_has_auto_migrate; then

            _tf_ok "Database.Migrate" \
                "detected"

        else

            _tf_item "Database.Migrate" \
                "not detected"

        fi


        if _tfhow_has_ensure_created; then

            _tf_ok "EnsureCreated" \
                "detected"

        else

            _tf_item "EnsureCreated" \
                "not detected"

        fi


        if _tfhow_has_ensure_deleted; then

            _tf_bad "EnsureDeleted" \
                "detected"
        fi


        printf '\n'

        if (( migrations > 0 )) &&
           ! _tfhow_has_auto_migrate &&
           ! _tfhow_has_ensure_created
        then

            _tf_warn "Conclusion" \
                "database schema appears to be externally prepared"

            _tf_dim \
                "Do not assume 'dotnet ef database update' is safe."

        fi

        ;;


    # ========================================================================
    # MIGRATIONS
    # ========================================================================

    migrations|migration|mig)

        _tf_title "MIGRATION STARTUP ANALYSIS"

        local migrations=0
        migrations="$(_tfhow_migration_count)"


        _tf_section "Status"

        _tf_label "migration files"
        _tf_value "$migrations"


        if _tfhow_has_auto_migrate; then

            _tf_label "startup behavior"
            _tf_cfgval "Database.Migrate() detected"

        elif _tfhow_has_ensure_created; then

            _tf_label "startup behavior"
            _tf_cfgval "EnsureCreated() detected"

        else

            _tf_label "startup behavior"
            _tf_value "no schema initialization detected"

        fi


        _tf_section "Migration Locations"

        fd \
            -t d \
            '^Migrations$' \
            --exclude bin \
            --exclude obj \
            . 2>/dev/null |
        while IFS= read -r dir; do

            local count=0

            count="$(
                fd \
                    -e cs \
                    . \
                    "$dir" \
                    2>/dev/null |
                rg -v '\.Designer\.cs$|ModelSnapshot\.cs$' |
                wc -l |
                tr -d ' '
            )"

            _tf_label "$dir"
            _tf_value "$count"

        done


        _tf_section "Automatic Migration Evidence"

        local evidence=""

        evidence="$(
            _tfhow_rg -n \
                '\.Database\.Migrate(Async)?[[:space:]]*\(|EnsureCreated(Async)?[[:space:]]*\(|EnsureDeleted(Async)?[[:space:]]*\(' \
                -g '*.cs' \
                . 2>/dev/null |
            head -100
        )"


        [[ -n "$evidence" ]] &&
            printf '%s\n' "$evidence" ||
            _tf_dim "No automatic migration/schema calls found."


        _tf_section "Documentation Evidence"

        local docs=""

        docs="$(
            _tfhow_rg -n \
                -i \
                'dotnet ef database update|database migration|apply migrations|run migrations|migration' \
                -g 'README*' \
                -g '*.md' \
                . 2>/dev/null |
            head -80
        )"


        [[ -n "$docs" ]] &&
            printf '%s\n' "$docs" ||
            _tf_dim "No migration instructions found in documentation."


        printf '\n'
        _tf_warn "READ ONLY" \
            "tfhow never applies migrations"

        ;;


    # ========================================================================
    # DOCKER
    # ========================================================================

    docker|containers)

        _tf_title "CONTAINER / COMPOSE ANALYSIS"

        _tf_section "Compose Files"

        local compose=""
        compose="$(_tfhow_compose_files)"


        if [[ -n "$compose" ]]; then

            while IFS= read -r file; do

                _tf_path "$file"

                if command -v yq >/dev/null 2>&1; then

                    local services=""

                    services="$(
                        yq \
                            '.services | keys | .[]' \
                            "$file" \
                            2>/dev/null
                    )"

                    if [[ -n "$services" ]]; then

                        while IFS= read -r service; do
                            _tf_sub "service" "$service"
                        done <<< "$services"

                    fi

                fi

            done <<< "$compose"

        else

            _tf_dim "No Compose files detected."

        fi


        _tf_section "Dockerfiles / Containerfiles"

        local dockerfiles=""
        dockerfiles="$(_tfhow_dockerfiles)"


        if [[ -n "$dockerfiles" ]]; then

            while IFS= read -r file; do
                _tf_path "$file"
            done <<< "$dockerfiles"

        else

            _tf_dim "No Dockerfile/Containerfile detected."

        fi


        _tf_section "Container Images"

        _tfhow_rg \
            '^[[:space:]]*image:[[:space:]]*' \
            -g '*.yml' \
            -g '*.yaml' \
            . 2>/dev/null |
        sed \
            's/^[^:]*://' |
        sed \
            's/^[[:space:]]*//' |
        sort -u |
        head -100


        _tf_section "Compose Dependencies"

        _tfhow_rg -n \
            'depends_on:|healthcheck:|condition:[[:space:]]*service_' \
            -g '*.yml' \
            -g '*.yaml' \
            . 2>/dev/null |
        head -100


        printf '\n'
        _tf_warn "READ ONLY" \
            "Docker/Podman was not started or queried"

        ;;


    # ========================================================================
    # SECRETS
    # ========================================================================

    secrets|secret)

        _tf_title "SECRET / EXTERNAL CONFIG ANALYSIS"

        _tf_section ".NET User Secrets"

        local secret_ids=""

        secret_ids="$(
            _tfhow_rg -o \
                '<UserSecretsId>[^<]+' \
                -g '*.csproj' \
                . 2>/dev/null |
            sed 's/.*<UserSecretsId>//' |
            sort -u
        )"


        if [[ -n "$secret_ids" ]]; then

            while IFS= read -r id; do

                _tf_label "UserSecretsId"
                _tf_cfgval "$id"

            done <<< "$secret_ids"

        else

            _tf_dim "No UserSecretsId detected."

        fi


        _tf_section "Secret-Like Configuration References"

        _tfhow_rg -n \
            -i \
            '(password|passwd|secret|apikey|api_key|clientsecret|token|certificate|thumbprint)' \
            -g '*.cs' \
            -g '*.json' \
            -g '*.yml' \
            -g '*.yaml' \
            -g '*.config' \
            -g '*.xml' \
            --glob '!**/bin/**' \
            --glob '!**/obj/**' \
            . 2>/dev/null |
        sed -E \
            's/("(password|passwd|secret|apikey|api_key|clientsecret|token)"[[:space:]]*:[[:space:]]*")[^"]+/\1<redacted>/Ig' |
        head -120


        _tf_section "Environment Files"

        local envfiles=""

        envfiles="$(
            fd \
                -t f \
                '^\.env(\..*)?$' \
                --exclude node_modules \
                . 2>/dev/null
        )"


        if [[ -n "$envfiles" ]]; then

            while IFS= read -r file; do
                _tf_path "$file"
            done <<< "$envfiles"

        else

            _tf_dim "No .env files detected."

        fi


        printf '\n'
        _tf_warn "Safety" \
            "values from User Secrets are not read"

        ;;


    # ========================================================================
    # PORTS
    # ========================================================================

    ports|port)

        _tf_title "PORT / URL MAP"


        _tf_section "Launch Settings"

        local launchfiles=""
        launchfiles="$(_tfhow_launchsettings)"


        if [[ -n "$launchfiles" ]]; then

            while IFS= read -r file; do

                _tf_path "$file"

                if command -v jq >/dev/null 2>&1; then

                    jq -r \
                        '.profiles // {} |
                         to_entries[] |
                         select(.value.applicationUrl != null) |
                         "\(.key)|\(.value.applicationUrl)"' \
                        "$file" \
                        2>/dev/null |
                    while IFS='|' read -r profile url; do

                        _tf_label "$profile"
                        _tf_cfgval "$url"

                    done

                else

                    _tfhow_rg -n \
                        'applicationUrl' \
                        "$file" \
                        2>/dev/null

                fi

            done <<< "$launchfiles"

        else

            _tf_dim "No launchSettings.json detected."

        fi


        _tf_section "Compose Ports"

        _tfhow_rg -n \
            '^[[:space:]]*-[[:space:]]*["'\'']?[0-9]+:[0-9]+' \
            -g '*.yml' \
            -g '*.yaml' \
            . 2>/dev/null |
        head -100


        _tf_section "URLs in Configuration"

        _tfhow_rg -o \
            'https?://[^"'\'', }<]+' \
            -g '*.json' \
            -g '*.cs' \
            -g '*.config' \
            -g '*.xml' \
            -g '*.yml' \
            -g '*.yaml' \
            . 2>/dev/null |
        sort -u |
        head -120

        ;;


    # ========================================================================
    # ENV
    # ========================================================================

    env|environment)

        _tf_title "ENVIRONMENT REQUIREMENTS"


        _tf_section "ASP.NET Environment"

        _tfhow_rg -n \
            'ASPNETCORE_ENVIRONMENT|DOTNET_ENVIRONMENT|IsDevelopment\(|IsProduction\(|IsEnvironment\(' \
            -g '*.cs' \
            -g '*.json' \
            -g '*.yml' \
            -g '*.yaml' \
            . 2>/dev/null |
        head -100


        _tf_section "Environment Variable Reads"

        {
            _tfhow_rg -o \
                'Environment\.GetEnvironmentVariable\("[^"]+"' \
                -g '*.cs' \
                . 2>/dev/null |
            sed \
                's/.*GetEnvironmentVariable("//; s/"$//'

            _tfhow_rg -o \
                'ConnectionStrings__[A-Za-z0-9_.:-]+' \
                -g '*.yml' \
                -g '*.yaml' \
                -g '*.env' \
                . 2>/dev/null

        } |
        sort -u |
        head -150


        _tf_section "Environment Files"

        fd \
            -t f \
            '^\.env(\..*)?$' \
            --exclude node_modules \
            . 2>/dev/null |
        while IFS= read -r file; do
            _tf_path "$file"
        done

        ;;


    # ========================================================================
    # ORDER
    # ========================================================================

    order|sequence)

        _tf_title "LIKELY STARTUP SEQUENCE"

        local startup=""
        local migrations=0
        local compose=""
        local keys=""
        local step=1

        startup="$(_tfhow_primary_startup)"
        migrations="$(_tfhow_migration_count)"
        compose="$(_tfhow_compose_files)"
        keys="$(_tfhow_connection_keys)"


        if [[ -n "$compose" ]]; then

            _tfhow_step "$step" \
                "Review required infrastructure"

            while IFS= read -r file; do
                _tf_sub "compose" "$file"
            done <<< "$compose"

            (( step++ ))

        fi


        if [[ -n "$keys" ]]; then

            _tfhow_step "$step" \
                "Resolve database connection strings"

            while IFS= read -r key; do
                _tf_sub "connection" "$key"
            done <<< "$keys"

            (( step++ ))

        fi


        if _tfhow_has_user_secrets; then

            _tfhow_step "$step" \
                "Verify required User Secrets"

            (( step++ ))

        fi


        if (( migrations > 0 )); then

            _tfhow_step "$step" \
                "Verify database schema"

            if _tfhow_has_auto_migrate; then

                _tf_sub "behavior" \
                    "application appears to migrate automatically"

            else

                _tf_sub "behavior" \
                    "application does NOT appear to migrate automatically"

                _tf_sub "warning" \
                    "do not apply migrations until team workflow is known"

            fi

            (( step++ ))

        fi


        if _tfhow_has_frontend; then

            local pm=""
            pm="$(_tfhow_package_manager)"

            _tfhow_step "$step" \
                "Verify frontend dependencies"

            [[ -n "$pm" ]] &&
                _tf_sub "package manager" "$pm"

            (( step++ ))

        fi


        if _tfhow_has_https; then

            _tfhow_step "$step" \
                "Verify HTTPS/development certificate"

            (( step++ ))

        fi


        if [[ -n "$startup" ]]; then

            _tfhow_step "$step" \
                "Run application"

            _tf_sub "command" \
                "dotnet run --project $startup"

        else

            _tfhow_step "$step" \
                "Determine startup project"

        fi


        printf '\n'
        _tf_warn "Not executed" \
            "this is an inferred sequence only"

        ;;


    # ========================================================================
    # EVIDENCE
    # ========================================================================

    evidence|ev)

        _tf_title "STARTUP EVIDENCE"

        _tf_section "Documentation"

        local docs=""
        docs="$(_tfhow_readme_run_evidence)"

        [[ -n "$docs" ]] &&
            printf '%s\n' "$docs" ||
            _tf_dim "No useful README startup evidence found."


        _tf_section "Program / Host"

        _tfhow_rg -n \
            'CreateBuilder|CreateHostBuilder|AddDbContext|AddNpgsqlDbContext|AddSqlServerDbContext|AddRedis|AddStackExchangeRedis|AddAuthentication|AddAuthorization|AddGrpc|MapGrpcService|app\.Run\(' \
            -g '*.cs' \
            . 2>/dev/null |
        head -150


        _tf_section "Configuration"

        _tfhow_rg -n \
            'GetConnectionString|GetSection|AddJsonFile|AddEnvironmentVariables|GetEnvironmentVariable|UserSecretsId' \
            -g '*.cs' \
            -g '*.csproj' \
            . 2>/dev/null |
        head -150


        _tf_section "Database Initialization"

        _tfhow_rg -n \
            'Database\.Migrate|EnsureCreated|EnsureDeleted|dotnet ef database update' \
            -g '*.cs' \
            -g '*.md' \
            . 2>/dev/null |
        head -100

        ;;


    # ========================================================================
    # WHY
    # ========================================================================

    why)

        local thing="$1"

        [[ -z "$thing" ]] && {
            echo "Usage: tfhow why <thing>"
            return 1
        }


        _tf_title "WHY: $thing"

        _tf_section "Source Evidence"

        local hits=""

        hits="$(
            _tfhow_rg -n \
                -i \
                -- "$thing" \
                -g '*.cs' \
                -g '*.csproj' \
                -g '*.json' \
                -g '*.config' \
                -g '*.xml' \
                -g '*.props' \
                -g '*.targets' \
                -g '*.yml' \
                -g '*.yaml' \
                -g '*.env' \
                -g '*.md' \
                . 2>/dev/null |
            head -150
        )"


        if [[ -n "$hits" ]]; then

            printf '%s\n' "$hits"

        else

            _tf_warn "evidence" "no matches"
            return

        fi


        _tf_section "Interpretation"


        if _tfhow_rg -q \
            "GetConnectionString\\(\"$thing\"" \
            -g '*.cs' \
            . 2>/dev/null
        then

            _tf_database \
                "'$thing' is consumed as a connection string"

        fi


        if _tfhow_rg -q \
            "GetSection\\(\"$thing\"" \
            -g '*.cs' \
            . 2>/dev/null
        then

            _tf_tech \
                "'$thing' is consumed as a configuration section"

        fi


        if _tfhow_rg -q \
            "<ProjectReference[^>]+$thing" \
            -g '*.csproj' \
            . 2>/dev/null
        then

            _tf_tech \
                "'$thing' participates in project dependencies"

        fi


        if _tfhow_rg -q \
            "$thing" \
            -g 'docker-compose*.yml' \
            -g 'docker-compose*.yaml' \
            -g 'compose*.yml' \
            -g 'compose*.yaml' \
            . 2>/dev/null
        then

            _tf_tech \
                "'$thing' appears in container orchestration"

        fi


        if _tfhow_rg -q \
            "$thing" \
            -g '*Migrations/*.cs' \
            . 2>/dev/null
        then

            _tf_database \
                "'$thing' appears in EF migration history"

        fi

        ;;

    # ========================================================================
    # PROJECT
    # ========================================================================

    project|proj)

        local query="$1"
        local action="${2:-summary}"

        if [[ -z "$query" ]]; then
            echo "Usage:"
            echo "  tfhow project <name|path>"
            echo "  tfhow project <name|path> blockers"
            echo "  tfhow project <name|path> order"
            echo "  tfhow project <name|path> evidence"
            return 1
        fi

        local result=""
        result="$(_tfhow_resolve_project "$query")"
        local rc=$?

        if (( rc == 2 )); then

            _tf_title "AMBIGUOUS PROJECT"

            printf '%s\n' "$result" |
                tail -n +2 |
                while IFS= read -r project; do
                    [[ -z "$project" ]] && continue
                    _tf_path "$project"
                done

            printf '\n'
            _tf_warn "project" \
                "use a more specific name or csproj path"

            return 2

        elif (( rc != 0 )) || [[ -z "$result" ]]; then

            _tf_bad "project" \
                "could not resolve '$query'"

            return 1
        fi

        local project="$result"

        case "$action" in

            summary|overview|ov)

                _tf_title "HOW TF: $(_tfhow_project_name "$project")"

                _tfhow_print_project_summary "$project"

                _tf_section "Blockers"
                _tfhow_project_blockers "$project"

                _tf_section "Likely Startup Order"
                _tfhow_project_order "$project"

                ;;


            blockers|blocker)

                _tf_title "PROJECT BLOCKERS"
                _tfhow_project_blockers "$project"

                ;;


            order|sequence)

                _tf_title "PROJECT STARTUP ORDER"
                _tfhow_project_order "$project"

                ;;


            evidence|ev)

                _tf_title "PROJECT STARTUP EVIDENCE"

                _tf_label "project"
                _tf_pathval "$project"

                _tf_section "Startup"

                _tfhow_scope_rg "$project" \
                    -n \
                    'CreateBuilder|CreateHostBuilder|AddDbContext|AddNpgsqlDbContext|AddSqlServerDbContext|AddRedis|AddStackExchangeRedis|AddAuthentication|AddAuthorization|AddGrpc|MapGrpcService|app\.Run\(' \
                    -g '*.cs' \
                    2>/dev/null |
                head -150

                _tf_section "Configuration"

                _tfhow_scope_rg "$project" \
                    -n \
                    'GetConnectionString|GetSection|GetEnvironmentVariable|AddJsonFile|AddEnvironmentVariables' \
                    -g '*.cs' \
                    2>/dev/null |
                head -150

                _tf_section "Schema"

                _tfhow_scope_rg "$project" \
                    -n \
                    'Database\.Migrate|EnsureCreated|EnsureDeleted' \
                    -g '*.cs' \
                    2>/dev/null |
                head -100

                ;;


            *)

                echo "Unknown project action: $action"
                echo
                echo "Supported:"
                echo "  summary"
                echo "  blockers"
                echo "  order"
                echo "  evidence"

                return 1
                ;;

        esac

        ;;


    # ========================================================================
    # ALL RUNNABLE PROJECTS
    # ========================================================================

    all)

        _tf_title "ALL RUNNABLE PROJECTS"

        local runnable=""
        runnable="$(_tfhow_runnable_projects)"

        if [[ -z "$runnable" ]]; then
            _tf_warn "startup" "no runnable projects detected"
            return
        fi

        while IFS= read -r project; do

            [[ -z "$project" ]] && continue

            _tfhow_print_project_summary "$project"

            printf '\n'

            _tf_sub "blockers" ""

            _tfhow_project_blockers "$project"

        done <<< "$runnable"

        ;;
    # ========================================================================
    # HELP
    # ========================================================================

    help|-h|--help)

        cat <<'EOF'

tfhow - deterministic startup archaeology

  tfhow
      Answer "how TF do I run this?"

  tfhow startup
      Identify and rank likely startup projects.

  tfhow blockers
      Show likely startup blockers and unknowns.

  tfhow config
      Explain configuration sources and required keys.

  tfhow infra
      Detect databases, Redis, RabbitMQ, Kafka, gRPC, auth, etc.

  tfhow db
      Database startup requirements.

  tfhow migrations
      Determine how schema initialization appears to work.

  tfhow docker
      Inspect Compose/Docker/Containerfile infrastructure.

  tfhow secrets
      Find secret dependencies without reading User Secret values.

  tfhow ports
      Map launch URLs, ports and configured URLs.

  tfhow env
      Find environment-dependent behavior and variable reads.

  tfhow order
      Produce the likely first-run sequence.

  tfhow evidence
      Show the raw evidence behind startup inference.

  tfhow why THING
      Explain why a particular service/config/key/file matters.


SAFETY

  tfhow is intentionally read-only.

  It DOES NOT:

      run dotnet
      start containers
      contact databases
      apply migrations
      delete databases
      modify configuration
      read User Secret values


PHILOSOPHY

  FACT:
      "17 migrations exist"

  FACT:
      "Database.Migrate() was not found"

  INFERENCE:
      "database schema appears externally prepared"

  NOT ASSUMED:
      "you should run dotnet ef database update"

EOF

        ;;


    # ========================================================================
    # UNKNOWN
    # ========================================================================

    *)

        echo "tfhow: unknown command: $cmd"
        echo
        echo "Run:"
        echo "  tfhow help"

        return 1

        ;;

    esac
}
