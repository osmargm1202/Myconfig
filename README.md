## Myconfig

### Inicial

```
git clone https://github.com/tuusuario/Myconfig.git
cp -r Myconfig/* ~/.config/
```

### seguimiento

```
cd Myconfig
git pull origin master
cp -r * ~/.config/
```

### GameMode
```
cd Myconfig
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
cp game-mode.sh ~/.local/bin
chmod +x ~/.local/bin/game-mode.sh
```
