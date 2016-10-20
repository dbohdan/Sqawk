![A squawk](squawk.jpg)

[![Travis CI build status](https://travis-ci.org/dbohdan/sqawk.svg?branch=master)](https://travis-ci.org/dbohdan/sqawk)
[![AppVeyor CI build status](https://ci.appveyor.com/api/projects/status/github/dbohdan/sqawk?branch=master&svg=true)](https://ci.appveyor.com/project/dbohdan/sqawk)

**Sqawk** is an [Awk](http://awk.info/)-like program that uses SQL and can combine data from multiple files. It is powered by SQLite.

# Usage

`sqawk [globaloptions] script [option=value ...] < filename`

or

`sqawk [globaloptions] script [option=value ...] filename1 [[option=value ...] filename2 ...]`

One of the filenames can be `-` for the standard input.

## An example

Here is a somewhat contrived example that shows a script, a global option and several file options in use:

```sh
# List all login shells used on the system.
sqawk -ORS '\n' 'select distinct shell from passwd order by shell' FS=: columns=username,password,uid,gui,info,home,shell table=passwd /etc/passwd
```

or

```sh
# Do the same thing.
sqawk 'select distinct a7 from a order by a7' FS=: /etc/passwd
```

Sqawk allows you to be verbose to better document your script but aims to provide reasonable defaults that save you keystrokes in interactive use.

[Skip down](#more-examples) for more examples.

## SQL

A Sqawk `script` consist of one of more SQL statements in the SQLite version 3 dialect of SQL.

The default table names are `a` for the first input file, `b` for the second, `c` for the third, etc. You can change the table name for any one file with a file option. The table name is used as a prefix in its fields' names; the fields are named `a1`, `a2`, etc. in the table `a`, `b1`, `b2`, etc. in `b` and so on. `a0` is the raw input text of the whole record for each record (i.e., one line of input with the default record separator of `\n`). `anr` in `a`, `bnr` in `b` and so on contains the record number and is the primary key of its respective table. `anf`, `bnf` and so on contain the field count for a given record.

## Options

### Global options

These options affect all files.

| Option | Example | Comment |
|--------|---------|---------|
| -FS value | `-FS '[ \t]+'` | Input field separator for the default parser (one for all input files). |
| -RS value | `-RS '\n'` | Input record separator for the default parser (one for all input files). |
| -OFS value | `-OFS ' '` | Output field separator for the default serializer. |
| -ORS value | `-ORS '\n'` | Output record separator for the default serializer. |
| -NF value | `-NF 10` | The maximum number of fields per record. Increase this if you get errors like `table x has no column named x51` (`MNF=normal` only). |
| -MNF value | `-MNF expand`, `-MNF crop`, `-MNF normal` | The NF mode used if a record exceed the maximum number of fields: `expand` means to increase `NF` automatically and expand (alter) the table during import if the record contains more fields than available; `crop` means truncate the record to `NF` fields (fields after that will be not imported); `normal` makes Sqawk produce an error like `table x has no column named x11`. |
| -IMPF value | `-IMPF nr,nf,0-`, `-IMPF 1-2` | Fields to be imported into the table (default `nr,nf,0-`). The last value should be a numeric indices (from?-?to??). Can be used to exact specifying which fields should be imported from input. (increases import performance, minimizes overhead and simplifies output of statements like `select * from a`, if e. g. fields like `anr`, `anf` and `a0` are not necessary or too many input fields available). |
| -output value | `-output awk` | The output format. See [Output formats](#output-formats). |
| -v | | Print the Sqawk version and exit. |
| -1 | | Do not split records into fields. Same as `-F '^$'`. Allows you to avoid adjusting `-NF` and improves the performance somewhat for when you only want to operate on lines. |

#### Output formats

The following are the possible values for the command line option `-output`. The format options can follow the format name after a comma and are separated with commas, e.g., `-output json,arrays=0,indent=1`.

| Format name | Format options | Examples | Comment |
|-------------|----------------|----------|---------|
| awk | none | `-output awk` | The `awk` serializer behaves similarly to Awk. When it is selected Sqawk outputs each column of each of the database rows returned by your query separated from the next with the output field separator (-OFS); the rows themselves are in turn separated with the output record separator (-ORS). |
| csv | none | `-output csv` | Output CSV. |
| json | `arrays` (defaults to `0`), `indent` (defaults to `0`) | `-output json,indent=0,arrays=1` | Output the result of the query as JSON. If `arrays` is `0` result is an array of JSON objects with the column names as keys; if `arrays` is `1` the result is an array of arrays. The values are all represented as strings in either case. If `indent` is `1` each object will be indented for readability. |
| table | `alignments` or `align`, `margins`, `style` | `-output table,align=center left right`, `-output table,alignments=c l r` | Output plain text tables. The `table` serializer uses [Tabulate](http://tcl.wiki/41682) to format the output as a table using box-drawing characters. Note that the default Unicode table output will not display correctly in `cmd.exe` on Windows even after `chcp 65001`. Use `style=loFi` to draw tables with plain ASCII characters instead. |
| tcl | `dicts` (defaults to `0`) | `-output tcl,dicts=1` | Dump raw Tcl data structures. With the `tcl` serializer Sqawk outputs a list of lists if `dicts` is `0` and a list of dictionaries with the column names as keys if `dicts` is `1`. |

### Per-file options

These options are set before a filename and only affect one input source.

| Option | Example | Comment |
|--------|---------|---------|
| columns | `columns=id,name,sum`, `columns=id,a long name with spaces` | Set custom column names for the next file. If there are more columns than custom names the columns after the last one with a custom name will be named automatically in the same manner as for the option `header=1`. Custom column names override names taken from the header. If you give a column an empty name it will be named automatically or retain the name from the header. |
| datatypes | `datatypes=integer,real,text` | Set the [datatypes](https://www.sqlite.org/datatype3.html) for the columns, starting with `a1` if your table is named `a`. The datatype for each column for which the datatype is not explicitly given is `INTEGER`. The datatype of `a0` is always `TEXT`. |
| format | `format=csv csvsep=;` | Set the input format for the next source of input. See [Input formats](#input-formats). |
| header | `header=1` | Can be 0/false or 1. Use the first row of the file as a source of column names. If the first row has five fields then the first five columns will have custom names and all the following columns will have automatically generated names (e.g., `name`, `surname`, `title`, `office`, `phone`, `a6`, `a7`, ...). |
| merge | `merge=1-2,3-5`, `'merge=1 2 3 5'` | Merge fields with the given numbers into one preserving the separator characters between them. |
| prefix | `prefix=x` | Column name prefix in the table. Defaults to the table name. Specifying `table=foo` and `prefix=bar` will lead to you being able to use queries like `select bar1, bar2 from foo`.  |
| table | `table=foo` | Table name. By default tables are named `a`, `b`, `c`, ... Specifying `table=foo` for the second file only will result in tables having the names `a`, `foo`, `c`, ...  |
| NF | `NF=20` | Same as -NF but for one file. |
| MNF | `MNF=crop` | Same as -MNF but for one file (table). |
| IMPF | `IMPF=nr,nf,0-`, `IMPF=nr,2-5` | Importable fields, same as -IMPF but for one file (table). |

#### Input formats

A format option (`format=x`) selects the input parser with which Sqawk will parse the next input source. Formats can have multiple synonymous names or multiple names that produce slightly different effects. Selecting an input format can enable additional per-file options that only work with that format.

| Format | Additional options | Examples | Comment |
|--------|--------------------|--------- |---------|
| `awk` or `raw` | `FS`, `RS`, `trim` | `RS=\n`, `FS=:`, `trim=left` | The default input parser. Splits input into records then fields using regular expressions. The options `FS` and `RS` work the same as -FS and -RS respectively but only apply to one file. The option `trim` removes whitespace at the beginning of each line of input (`trim=left`), at its end (`trim=right`), both (`trim=both`) or none (`trim=none`). |
| `csv`, `csv2`, `csvalt` | `csvsep`, `csvquote` | `format=csv csvsep=, 'csvquote="'` | Parse the input as CSV. Using `format=csv2` or `format=csvalt` enables [alternate mode](http://core.tcl-lang.org/tcllib/doc/trunk/embedded/www/tcllib/files/modules/csv/csv.html#section3) for parsing CSV files exported by Microsoft Excel. `csvsep` specifies the field separator; it defaults to `,`. `csvquote` selects what characters fields that themselves contain the separator are quotes with; it defaults to `"`. Note that only some characters can be used as `csvquote`. |

# More examples

## Sum up numbers

    find . -iname '*.jpg' -type f -printf '%s\n' | sqawk 'select sum(a1)/1024/1024 from a'

## Line count

    sqawk -1 'select count(*) from a' < file.txt

## Find lines that match a pattern

    ls | sqawk -1 'select a0 from a where a0 like "%win%"'

## Shuffle lines

    sqawk -1 'select a1 from a order by random()' < file

## Pretty-print data as a table

    ps | sqawk -output table 'select a1,a2,a3,a4 from a' trim=left

### Sample output

```
┌─────┬─────┬────────┬───────────────┐
│ PID │ TTY │  TIME  │      CMD      │
├─────┼─────┼────────┼───────────────┤
│11476│pts/3│00:00:00│       ps      │
├─────┼─────┼────────┼───────────────┤
│11477│pts/3│00:00:00│tclkit-8.6.3-mk│
├─────┼─────┼────────┼───────────────┤
│20583│pts/3│00:00:02│      zsh      │
└─────┴─────┴────────┴───────────────┘
```

## Convert input to JSON objects

    ps | sqawk -output json,indent=1 'select PID,TTY,TIME,CMD from a' trim=left header=1

### Sample output

```
[{
    "PID"  : "3947",
    "TTY"  : "pts/2",
    "TIME" : "00:00:07",
    "CMD"  : "zsh"
},{
    "PID"  : "15951",
    "TTY"  : "pts/2",
    "TIME" : "00:00:00",
    "CMD"  : "ps"
},{
    "PID"  : "15952",
    "TTY"  : "pts/2",
    "TIME" : "00:00:00",
    "CMD"  : "tclkit-8.6.3-mk"
}]
```

## Find duplicate lines

Print them and how many times they are repeated.

    sqawk -1 -OFS ' -- ' 'select a0, count(*) from a group by a0 having count(*) > 1' < file

### Sample output

    13 -- 2
    16 -- 3
    83 -- 2
    100 -- 2

## Remove blank lines

    sqawk -1 -RS '[\n]+' 'select a0 from a' < file

## Sum up numbers with the same key

    sqawk -FS , -OFS , 'select a1, sum(a2) from a group by a1' data

This is the equivalent of the Awk code

    awk 'BEGIN { FS = OFS = ","} { s[$1] += $2 }; END { for(key in s) { print key, s[key]; } }' data

### Input

```
1015,5
1015,4
1035,17
1035,11
1009,1
1009,4
1026,9
1004,5
1004,5
1009,1
```

### Output

```
1004,10
1009,6
1015,9
1026,9
1035,28
```

## Combine data from two files

### Commands

This example uses the files from the [happypenguin.com 2013 data dump](https://archive.org/details/happypenguin_xml_dump_2013) to generate metadata.

    # Generate input files -- see below
    cd happypenguin_dump/screenshots
    md5sum * > MD5SUMS
    du -b * > du-bytes
    # Perform query
    sqawk 'select a1, b1, a2 from a inner join b on a2 = b2 where b1 < 10000 order by b1' MD5SUMS du-bytes

You don't need to download the data yourself to recreate `MD5SUMS` and `du-bytes`; the files can be found in  the directory [`examples/`](./examples/).

### Input files

#### MD5SUMS

```
d2e7d4d1c7587b40ef7e6637d8d777bc  0005.jpg
4e7cde72529efc40f58124f13b43e1d9  001.jpg
e2ab70817194584ab6fe2efc3d8987f6  0.0.6-settings.png
9d2cfea6e72d00553fb3d10cbd04f087  010_2.jpg
3df1ff762f1b38273ff2a158e3c1a6cf  0.10-planets.jpg
0be1582d861f9d047f4842624e7d01bb  012771602077.png
60638f91b399c78a8b2d969adeee16cc  014tiles.png
7e7a0b502cd4d63a7e1cda187b122b0b  017.jpg
[...]
```

#### du-bytes

```
136229  0005.jpg
112600  001.jpg
26651   0.0.6-settings.png
155579  010_2.jpg
41485   0.10-planets.jpg
2758972 012771602077.png
426774  014tiles.png
165354  017.jpg
[...]
```

### Output

```
d50700db41035eb74580decf83f83184 615 z81.png
e1b64d03caf4615d54e9022d5b13a22d 677 init.png
a0fb29411c169603748edcc02c0e86e6 823 agendaroids.gif
3b0c65213e121793d4458e09bb7b1f58 970 screen01.gif
05f89f23756e8ea4bc5379c841674a6e 999 retropong.png
a49a7b5ac5833ec365ed3cb7031d1d84 1458 fncpong.png
80616256c790c2a831583997a6214280 1516 el2_small.jpg
[...]
1c8a3cb2811e9c20572e8629c513326d 9852 7.png
c53a88c68b73f3c1632e3cdc7a0b4e49 9915 choosing_building.PNG
bf60508db16a92a46bbd4107f15730cd 9946 glad_shot01.jpg
```

# Installation

Sqawk requires Tcl 8.5 or newer, Tcllib and SQLite version 3 bindings for Tcl installed.

To install these dependencies on **Debian** and **Ubuntu** run the following command:

    sudo apt-get install tcl tcllib libsqlite3-tcl

On **Fedora**, **RHEL** and **CentOS**:

    su -
    yum install tcl tcllib sqlite-tcl

On **FreeBSD** with [pkgng](https://wiki.freebsd.org/pkgng):

    sudo pkg install tcl86 tcllib tcl-sqlite3
    sudo ln -s /usr/local/bin/tclsh8.6 /usr/local/bin/tclsh

On **Windows** the easiest option is to install [ActiveTcl](http://www.activestate.com/activetcl/downloads) from ActiveState.

On **OS X** use [MacPorts](https://www.macports.org/) or install [ActiveTcl](http://www.activestate.com/activetcl/downloads) for Mac. With MacPorts:

    sudo port install tcllib tcl-sqlite3

Once you have the dependencies installed run

    git clone https://github.com/dbohdan/sqawk
    cd sqawk
    make
    make test
    sudo make install

or on Windows

    git clone https://github.com/dbohdan/sqawk
    cd sqawk
    assemble.cmd
    tclsh tests.tcl

# License

MIT.

`lib/parsers/awk.tcl` contains code derived from Tcllib, which is licensed under the standard Tcl license. See `LICENSE.Tcllib`.

`squawk.jpg` photograph by [Terry Foote](https://en.wikipedia.org/wiki/User:Terry_Foote) at [English Wikipedia](https://en.wikipedia.org/wiki/). It is licensed under [CC BY-SA 3.0](http://creativecommons.org/licenses/by-sa/3.0/).
