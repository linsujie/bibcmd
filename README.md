# Concept
The bibcmd is a command-line and simplified version of the bibus.
It's developed to manage the bibliographies in pure command-line and keyboard.
The basic entry manipulated in the bibcmd is a 'term', which include the information of bibtex, the pdf files and perhaps your note on it.
The term is classified by the 'key', it could be tagged to multiple keys.

# Dependency
*   Both the binary library **ncurses** and **sqlite3** are needed by this script. Install them from the repositories (with apt-get, yum or dnf ...)
*   This script is writen in ruby, thus two gem are also necessary as the interfaces between the two library and ruby. Please do:

        gem install curses
        gem install sqlite3

# Configure
Please read the bibcmd and do as required.

File.expand_path('dir/.bibcmdrc') refer to the configure file, please read bibcmdrc.example for an example

In configure file

    USER_NAME : the name of USER
    DATA_FILE : the database
    REF_DIR   : dirctory to story files ( pdfs, links)
    READER    : primarily pdf reader
    ASSREADER : secondary pdf reader

# Command
## main screen
### command that would not change the data

    c  change the reading mode
    h  list the history
    l  list the lists
    L  list all terms
    R  refresh the panel
    s  open the search diaglog box

    o  open the term with primarily pdf reader, e.g. evince
    O  open the term with secondary pdf READER
    D  draw the logic pictrue of the list
    p  print the term
    P  print all term

    q  quit

### command that would change the data

    a  add a new term (The new term would be tagged with the key 'newtmp' by default)
    u  update the current term with new pdf file or bibtex File
    t  tag or untag the current term to a key
    d  delete the term
    n  note the term
***

## list (key)

    a  add a key as the son of current key
    A  add a key as the son of the origin key
    d  delete the key
    m  modify the key name
    l  link the key to another (or said, change the father of the key)

    zo unfold all the keys
    zm fold all the keys
    za change the current key folding state

    L  list the terms in the key and its offsprings
    [Enter] select the key (and list the terms of it)
    q quit the list
***

## adding note

    a  add a note
    d  delete the note
    m  modify the note
    p  pickup a note (to adjust its position)
    s  save notes
    q  quit the note mode
