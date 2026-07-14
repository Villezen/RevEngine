class BaseStickers extends Transition
{
    public function new() 
    {
        super('stickers'); 
    }

    public function start()
    {
        isStickers = true;

        stickerPacks =
        [
            {name: "base", folder: "set-1", items: ['bf', 'dad', 'gf', 'mom', 'monster', 'pico']},
            {name: "weekend", folder: "set-2", items: ['alucard', 'cassandra', 'cyclops', 'dad', 'darnell', 'misc', 'nene', 'pico', 'someDeadGuy']}
        ];
        activeStickerPack = "base";
        
        if (transOut) 
        {
            destroyStoredStickers();
            makeStickers(camera.width, camera.height);
        } 
        else 
        {
            if (Transition.storedStickers != null && Transition.storedStickers.members.length > 0) 
            {
                for (sticker in Transition.storedStickers.members) 
                    grpStickers.add(sticker);

                killStickers();
            } 
            else 
                finish();
        }
    }
}