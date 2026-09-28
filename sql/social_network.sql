
-- 1. CADASTRO DE USUÁRIOS
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    bio TEXT,
    current_job_title VARCHAR(100),
    company VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. GRUPOS TEMÁTICOS (Criado antes de posts para permitir FK)
CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_groups_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- 3. POSTAGENS (Postagens pessoais e em grupos)
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    group_id INT NULL, -- NULL se for postagem no perfil pessoal
    content TEXT NOT NULL,
    link_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_posts_group FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
);

-- 4. CONEXÕES / SEGUIDORES E AMIGOS
CREATE TABLE friends (
    id SERIAL PRIMARY KEY,
    follower_id INT NOT NULL,
    following_id INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'accepted', -- 'pending', 'accepted', 'blocked'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_friends_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_friends_following FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT unique_follower_following UNIQUE (follower_id, following_id),
    CONSTRAINT chk_friends_status CHECK (status IN ('pending', 'accepted', 'blocked')),
    CONSTRAINT chk_friends_not_self CHECK (follower_id <> following_id)
);

-- 5. COMENTÁRIOS
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 6. CURTIDAS (Posts e Comentários)
CREATE TABLE likes (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    post_id INT NULL,
    comment_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_likes_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    CONSTRAINT fk_likes_comment FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
    CONSTRAINT chk_like_target CHECK (
        (post_id IS NOT NULL AND comment_id IS NULL) OR 
        (post_id IS NULL AND comment_id IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_likes_user_post ON likes(user_id, post_id) WHERE post_id IS NOT NULL;
CREATE UNIQUE INDEX uq_likes_user_comment ON likes(user_id, comment_id) WHERE comment_id IS NOT NULL;

-- 7. MENSAGENS PRIVADAS
CREATE TABLE private_messages (
    id SERIAL PRIMARY KEY,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    message_text TEXT NOT NULL,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_messages_receiver FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 8. HABILIDADES DE PROGRAMAÇÃO
CREATE TABLE skills (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE user_skills (
    user_id INT NOT NULL,
    skill_id INT NOT NULL,
    experience_level VARCHAR(30) NOT NULL DEFAULT 'Iniciante', -- 'Iniciante', 'Intermediário', 'Avançado'
    PRIMARY KEY (user_id, skill_id),
    CONSTRAINT fk_user_skills_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_skills_skill FOREIGN KEY (skill_id) REFERENCES skills(id) ON DELETE CASCADE,
    CONSTRAINT chk_user_skills_experience CHECK (experience_level IN ('Iniciante', 'Intermediário', 'Avançado'))
);

-- 9. MEMBROS DOS GRUPOS
CREATE TABLE group_members (
    group_id INT NOT NULL,
    user_id INT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'member', -- 'admin', 'member'
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id),
    CONSTRAINT fk_group_members_group FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_group_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_group_members_role CHECK (role IN ('admin', 'member'))
);

-- Uma postagem em grupo só pode ser feita por um membro daquele grupo.
ALTER TABLE posts
    ADD CONSTRAINT fk_posts_group_member
    FOREIGN KEY (group_id, user_id)
    REFERENCES group_members(group_id, user_id)
    ON DELETE CASCADE;

-- 10. DESAFIOS DE PROGRAMAÇÃO
CREATE TABLE challenges (
    id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    difficulty VARCHAR(20) NOT NULL CHECK (difficulty IN ('Fácil', 'Médio', 'Difícil')),
    points INT NOT NULL DEFAULT 10 CHECK (points >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE challenge_submissions (
    id SERIAL PRIMARY KEY,
    challenge_id INT NOT NULL,
    user_id INT NOT NULL,
    code_solution TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- 'ACCEPTED', 'REJECTED', 'PENDING'
    score_earned INT NOT NULL DEFAULT 0 CHECK (score_earned >= 0),
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_submissions_challenge FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE,
    CONSTRAINT fk_submissions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_submission_status CHECK (status IN ('ACCEPTED', 'REJECTED', 'PENDING'))
);

-- 11. RANKING DOS USUÁRIOS
CREATE TABLE leaderboard (
    user_id INT PRIMARY KEY,
    total_score INT NOT NULL DEFAULT 0 CHECK (total_score >= 0),
    rank_position INT CHECK (rank_position > 0),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_leaderboard_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE FUNCTION refresh_user_leaderboard(p_user_id INT)
RETURNS VOID
LANGUAGE SQL
AS $$
    INSERT INTO leaderboard (user_id, total_score, updated_at)
    SELECT users.id,
        COALESCE(SUM(challenge_submissions.score_earned) FILTER (WHERE challenge_submissions.status = 'ACCEPTED'), 0),
        CURRENT_TIMESTAMP
    FROM users
    LEFT JOIN challenge_submissions ON challenge_submissions.user_id = users.id
    WHERE users.id = p_user_id
    GROUP BY users.id
    ON CONFLICT (user_id) DO UPDATE
    SET total_score = EXCLUDED.total_score,
        updated_at = EXCLUDED.updated_at;
$$;

CREATE FUNCTION update_leaderboard_after_submission()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM refresh_user_leaderboard(NEW.user_id);
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM refresh_user_leaderboard(OLD.user_id);
    ELSE
        PERFORM refresh_user_leaderboard(OLD.user_id);
        IF NEW.user_id <> OLD.user_id THEN
            PERFORM refresh_user_leaderboard(NEW.user_id);
        END IF;
    END IF;

    WITH ranked_users AS (
        SELECT user_id, RANK() OVER (ORDER BY total_score DESC) AS rank_position
        FROM leaderboard
    )
    UPDATE leaderboard AS current_rank
    SET rank_position = ranked_users.rank_position,
        updated_at = CURRENT_TIMESTAMP
    FROM ranked_users
    WHERE current_rank.user_id = ranked_users.user_id;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_update_leaderboard
AFTER INSERT OR UPDATE OR DELETE ON challenge_submissions
FOR EACH ROW
EXECUTE FUNCTION update_leaderboard_after_submission();

-- ============================================================
-- ÍNDICES PARA OTIMIZAÇÃO DE BUSCAS FREQUENTES
-- ============================================================
CREATE INDEX idx_posts_user ON posts(user_id);
CREATE INDEX idx_posts_group ON posts(group_id);
CREATE INDEX idx_comments_post ON comments(post_id);
CREATE INDEX idx_likes_post ON likes(post_id);
CREATE INDEX idx_likes_comment ON likes(comment_id);
CREATE INDEX idx_friends_following ON friends(following_id);
CREATE INDEX idx_messages_sender_receiver ON private_messages(sender_id, receiver_id);