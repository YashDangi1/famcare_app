-- ==============================================================
-- Migration: P3 Gamification (user_achievements)
-- Description: Adds a table to store unlocked achievements, syncing
-- them across devices rather than relying solely on SharedPreferences.
-- ==============================================================

-- 1. Create user_achievements table
CREATE TABLE IF NOT EXISTS public.user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, achievement_id) -- User can only unlock each achievement once
);

-- 2. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON public.user_achievements(user_id);

-- 3. Enable RLS
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
CREATE POLICY "Users can view their own achievements"
    ON public.user_achievements FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own achievements"
    ON public.user_achievements FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own achievements (for reset)"
    ON public.user_achievements FOR DELETE
    USING (auth.uid() = user_id);
