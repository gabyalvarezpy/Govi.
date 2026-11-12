-- GOVI: separar comentarios por foto dentro de cada álbum.
ALTER TABLE public.post_comments
ADD COLUMN IF NOT EXISTS media_index integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS post_comments_post_media_created_idx
ON public.post_comments (post_id, media_index, created_at);
