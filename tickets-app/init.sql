-- ============================================================
DROP TRIGGER IF EXISTS trg_sync_estado ON ticket_historial;
DROP TRIGGER IF EXISTS trg_log_ticket_creado ON tickets;
DROP FUNCTION IF EXISTS sync_ticket_estado();
DROP FUNCTION IF EXISTS log_ticket_creado();
DROP VIEW IF EXISTS v_tickets_7dias;
DROP TABLE IF EXISTS ticket_historial CASCADE;
DROP TABLE IF EXISTS tickets CASCADE;

-- ============================================================
-- TABLA PRINCIPAL DE TICKETS
-- ============================================================
CREATE TABLE tickets (
    ticket_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id          VARCHAR(100),
    thread_id         VARCHAR(100),
    email             VARCHAR(255) NOT NULL,
    subject           TEXT,
    message           TEXT,
    received_at       TIMESTAMPTZ,
    categoria         VARCHAR(10),
    sentimiento       VARCHAR(20),
    complejidad       VARCHAR(5),
    lenguaje_agresivo BOOLEAN,
    estado            VARCHAR(50),
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA DE HISTORIAL / TRAZABILIDAD
-- ============================================================
CREATE TABLE ticket_historial (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID NOT NULL REFERENCES tickets(ticket_id),
    estado      VARCHAR(50) NOT NULL,
    accion      TEXT,
    fecha       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TRIGGER 1: al insertar en ticket_historial sincroniza estado en tickets
-- ============================================================
CREATE OR REPLACE FUNCTION sync_ticket_estado()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE tickets
    SET estado = NEW.estado,
        updated_at = NOW()
    WHERE ticket_id = NEW.ticket_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_estado
AFTER INSERT ON ticket_historial
FOR EACH ROW
EXECUTE FUNCTION sync_ticket_estado();

-- ============================================================
-- TRIGGER 2: al crear un ticket registra automáticamente el primer historial
-- ============================================================
CREATE OR REPLACE FUNCTION log_ticket_creado()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO ticket_historial (ticket_id, estado, accion)
    VALUES (NEW.ticket_id, 'Recibido', 'Ticket creado por correo entrante');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_ticket_creado
AFTER INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION log_ticket_creado();

CREATE OR REPLACE VIEW v_tickets_7dias AS
SELECT 
    email,
    categoria,
    COUNT(*) as total
FROM tickets
WHERE 
    received_at >= NOW() - INTERVAL '7 days'
    AND estado NOT IN (
        'Resuelto automáticamente',
        'Cerrado por humano'
    )
GROUP BY email, categoria;
