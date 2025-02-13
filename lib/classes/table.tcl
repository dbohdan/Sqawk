# Sqawk, an SQL awk.
# Copyright (c) 2015-2018, 2020 D. Bohdan
# License: MIT

namespace eval ::sqawk {}

# Creates and populates an SQLite3 table with a specific format.
::snit::type ::sqawk::table {
    option -database
    option -dbtable
    option -columnprefix
    option -f0 true
    option -maxnf
    option -modenf -validatemethod Check-modenf -default error
    option -header -validatemethod Check-header -default {}
    option -datatypes {}

    destructor {
        [$self cget -database] eval "DROP TABLE [$self cget -dbtable]"
    }

    method Check-header {option value} {
        foreach item $value {
            if {[string match *`* $item]} {
                error {column names can't contain grave accents (`)}
            }
        }
    }

    method Check-modenf {option value} {
        if {$value ni {crop error expand}} {
            error [list invalid MNF value: $value]
        }
    }

    # Return the column name for column number $i, custom (if present) or
    # automatically generated.
    method column-name i {
        set customColName [lindex [$self cget -header] $i-1]
        if {($i > 0) && ($customColName ne "")} {
            return `$customColName`
        } else {
            return [$self cget -columnprefix]$i
        }
    }

    # Return the column datatype for column number $i, custom (if present) or
    # "INTEGER" otherwise.
    method column-datatype i {
        set customColDatatype [lindex [$self cget -datatypes] $i-1]
        if {$customColDatatype ne ""} {
            return $customColDatatype
        } else {
            return INTEGER
        }
    }

    # Create a database table for the table object.
    method initialize {} {
        set fields {}
        if {[$self cget -f0]} {
            lappend fields "[$self column-name 0] TEXT"
        }
        for {set i 1} {$i <= [$self cget -maxnf]} {incr i} {
            lappend fields "[$self column-name $i] [$self column-datatype $i]"
        }

        set colPrefix [$self cget -columnprefix]
        set command "CREATE TABLE IF NOT EXISTS [$self cget -dbtable] ("
        append command "\n    ${colPrefix}nr INTEGER PRIMARY KEY,"
        append command "\n    ${colPrefix}nf INTEGER"
        if {$fields ne {}} {
            append command ",\n    [join $fields ",\n    "]"
        }
        append command )

        [$self cget -database] eval $command
    }

    # Insert each row returned when you run the script $next into the database
    # table in a transaction. Finish when the script returns with -code
    # break.
    method insert-rows next {
        set db [$self cget -database]
        set colPrefix [$self cget -columnprefix]
        set tableName [$self cget -dbtable]

        set maxNF [$self cget -maxnf]
        set modeNF [$self cget -modenf]
        set curNF 0
        set f0 [$self cget -f0]
        set startF [expr {$f0 ? 0 : 1}]

        $db transaction {
            while 1 {
                set nf 0
                # [{*}$next] must return -code break when it runs out of data to
                # pass to us. That's how we leave this [while] loop.
                foreach field [{*}$next] {
                    set row($nf) $field
                    incr nf
                    # Crop (truncate row) if needed.
                    if {$modeNF eq "crop" && $nf > $maxNF} {
                        break
                    }
                }

                # Prepare the statement unless it's already been prepared and
                # cached. If the current row contains more fields than exist
                # alter the table adding columns.
                if {$nf != $curNF} {
                    set curNF $nf

                    if {[info exists rowInsertCommand($nf)]} {
                        set statement $rowInsertCommand($nf)
                    } else {
                        set insertColumnNames [list ${colPrefix}nf]
                        set insertValues [list \$nf]
                        for {set i $startF} {$i < $nf} {incr i} {
                            lappend insertColumnNames [$self column-name $i]
                            lappend insertValues \$row($i)
                        }

                        # Expand (alter) table if needed.
                        if {$modeNF eq "expand" && $nf - 1 > $maxNF} {
                            for {set i $maxNF; incr i} {$i < $nf} {incr i} {
                                $db eval "ALTER TABLE $tableName ADD COLUMN\
                                        [$self column-name $i]\
                                        [$self column-datatype $i]"
                            }
                            $self configure -maxnf [set maxNF [incr i -1]]
                        }

                        # Create a prepared statement.
                        set statement [set rowInsertCommand($nf) "
                        INSERT INTO $tableName ([join $insertColumnNames ,])
                        VALUES ([join $insertValues ,])
                        "]
                    }
                }

                incr nf -1
                $db eval $statement
                if {$nf > $startF} {
                    unset row
                }
            }
        }
    }
}
