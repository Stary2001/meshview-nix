clean_misc() {
    echo "Cleaning generated uv files"
    rm -f main.py
    rm -f .python-version

}
clean_all() {
    echo "Cleaning old uv files"
    clean_misc
    rm -f pyproject.toml
    rm -f uv.lock
}

clean_all

echo "Generatic new uv files"

uv init --python 3.12
uv add -r meshview/requirements.txt

clean_misc
