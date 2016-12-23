#!/usr/bin/env bash
#------------------------------------------------------------------------------
#
#  Taginfo Master DB
#
#  update.sh DATADIR
#
#------------------------------------------------------------------------------

set -e
set -u
set -x

readonly SRCDIR=$(dirname $(readlink -f "$0"))
readonly DATADIR=$1

if [ -z $DATADIR ]; then
    echo "Usage: update.sh DATADIR"
    exit 1
fi

readonly MASTER_DB=$DATADIR/taginfo-master.db
readonly HISTORY_DB=$DATADIR/taginfo-history.db
readonly SELECTION_DB=$DATADIR/selection.db

source $SRCDIR/../util.sh master

create_search_database() {
    local tokenizer=$(get_config sources.master.tokenizer simple)
    rm -f $DATADIR/taginfo-search.db
    run_sql DIR=$DATADIR TOKENIZER=$tokenizer $DATADIR/taginfo-search.db $SRCDIR/search.sql
}

create_master_database() {
    rm -f $MASTER_DB
    run_sql $MASTER_DB $SRCDIR/languages.sql
    run_sql DIR=$DATADIR $MASTER_DB $SRCDIR/master.sql
}

create_selection_database() {
    local min_count_tags=$(get_config sources.master.min_count_tags 10000)
    local min_count_for_map=$(get_config sources.master.min_count_for_map 1000)
    local min_count_relations_per_type=$(get_config sources.master.min_count_relations_per_type 100)

    rm -f $SELECTION_DB
    run_sql \
        DIR=$DATADIR \
        MIN_COUNT_FOR_MAP=$min_count_for_map \
        MIN_COUNT_TAGS=$min_count_tags \
        MIN_COUNT_RELATIONS_PER_TYPE=$min_count_relations_per_type \
        $SELECTION_DB $SRCDIR/selection.sql

    run_sql $SELECTION_DB $SRCDIR/../db/show_selection_stats.sql "Selection database contents:"
}

update_history_database() {
    if [ ! -e $HISTORY_DB ]; then
        print_message "No history database from previous runs. Initializing a new one..."
        run_sql $HISTORY_DB $SRCDIR/history_init.sql
    fi

    run_sql DIR=$DATADIR $HISTORY_DB $SRCDIR/history_update.sql
}

main() {
    print_message "Start master..."

    create_search_database
    create_master_database
    create_selection_database
    update_history_database

    print_message "Done master."
}

main

