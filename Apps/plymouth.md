# display archlinux logo
arch_image = Image("archlinux.png");
arch_sprite = Sprite();

arch_sprite.SetImage(arch_image);
arch_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - arch_image.GetWidth() / 2)); # center the image horizontally
arch_sprite.SetY(Window.GetHeight() - arch_image.GetHeight() - 50); # display just above the bottom of the screen