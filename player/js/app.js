// TODO: search with this index, it kinda works in the dev console
var songIndex = null

function initIndex(songMetadata) {
  songIndex = lunr(function () {
    this.ref('index')
    this.field('title')
    this.field('artist')
    this.field('album')
    this.field('genre')

    aux = songMetadata.map(function(doc) {
      return {
        "index": songMetadata.indexOf(doc),
        "title": doc.Title,
        "artist": doc.Artist,
        "album": doc.Album,
        "genre": doc.Genre,
      }
    })

    aux.forEach(function (doc) { this.add(doc) }, this)

  })
}

function initPlaylist(numSongs) {
  playlist = document.getElementById("playlist-container")
  while(playlist.firstChild){
    playlist.removeChild(playlist.firstChild);
  }
  for (i = 0; i < numSongs; i++) {
    playlist.insertAdjacentHTML('beforeend', makeSongContainer(i))
  }
}

function makeSongContainer(songIndex) {
  return `
    <div class="song amplitude-song-container amplitude-play-pause"  data-amplitude-song-index="${songIndex}">
      <div class="song-meta-data-container">
        <span class="song-name" data-amplitude-song-info="name" data-amplitude-song-index="${songIndex}"></span>
        <span class="song-artist" data-amplitude-song-info="artist" data-amplitude-song-index="${songIndex}"></span>
      </div>
    </div>
  `
}

function init() {
  fetch('api/meta')
    .then(resp => resp.json())
    .then(function(songMetadata) {
      songMetadata.sort(function(a, b) {
        // compare genre
        genrea = a.Genre.toUpperCase();
        genreb = b.Genre.toUpperCase();
        if (genrea < genreb) {
          return -1;
        }
        if (genrea > genreb) {
          return 1;
        }
        // tie breaker artist
        artista = a.Artist.toUpperCase();
        artistb = b.Artist.toUpperCase();
        if (artista < artistb) {
          return -1;
        }
        if (artista > artistb) {
          return 1;
        }
        // tie breaker album
        albuma = a.Album.toUpperCase();
        albumb = b.Album.toUpperCase();
        if (albuma < albumb) {
          return -1;
        }
        if (albuma > albumb) {
          return 1;
        }
        return 0;
      })
      return songMetadata
    })
    .then(function(songMetadata) {
      initIndex(songMetadata)
      initPlaylist(songMetadata.length)

      Amplitude.init({
        bindings: {
          37: 'prev',
          39: 'next',
          32: 'play_pause'
        },
        debug: true,
        songs: songMetadata.map(function(md) {
          return {
            "name": md.Title,
            "artist": md.Artist,
            "album": md.Album,
            "url": "../ui/download/"+md.BlobRef,
            "cover_art_url": "static/placeholder.png",
          }}
        ),

        waveforms: {
            sample_rate: 50
        },
      })
    })
}



