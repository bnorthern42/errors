# theflip.zsh
# Deterministic project archaeology for C#/.NET, JavaScript/TypeScript, and XML.
# Commands: tfcs, tfjs, tfx
#
# Core dependencies:
#   rg fd tokei git
# Recommended:
#   jq column
#
# Optional .NET-aware tooling:
#   roslynator       - deeper Roslyn-backed source analysis when installed
#   dotnet           - SDK/project metadata, package vulnerability checks, format/analyzer verification
#   csharpier        - detected and surfaced when installed
#
# This file is intentionally read-only against the inspected repository.
# It does not run format/fix, migrations, package installs, database updates, or writes.
#
# Install:
#   source /path/to/theFlip.zsh
# or:
#   echo 'source /path/to/theflip.zsh' >> ~/.zshrc

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
