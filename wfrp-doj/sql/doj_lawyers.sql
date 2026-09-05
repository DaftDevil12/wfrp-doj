-- wfrp-doj — lawyer register
--
-- This table is created automatically when the resource starts (see
-- server/lawyer.lua), so importing it by hand is optional. It is provided here
-- for reference / manual setup.
--
-- Rows are keyed by VORP's character identifier (characters.charidentifier).

CREATE TABLE IF NOT EXISTS `doj_lawyers` (
    `charidentifier` INT NOT NULL,
    `name`     VARCHAR(255) DEFAULT NULL,
    `hired_by` VARCHAR(255) DEFAULT NULL,
    `since`    INT DEFAULT NULL,
    PRIMARY KEY (`charidentifier`)
);

-- Lawyer ledger: one row per transaction. `amount` is signed — positive when a
-- bill is collected, negative when the lawyer withdraws. Balance = SUM(amount).
CREATE TABLE IF NOT EXISTS `doj_lawyer_ledger` (
    `id`             INT NOT NULL AUTO_INCREMENT,
    `charidentifier` INT NOT NULL,
    `type`           VARCHAR(16) NOT NULL,        -- 'bill' or 'withdraw'
    `amount`         DECIMAL(12,2) NOT NULL,      -- + collected, - withdrawn
    `party`          VARCHAR(255) DEFAULT NULL,   -- payer name (for bills)
    `reason`         VARCHAR(255) DEFAULT NULL,
    `created`        INT DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_doj_ledger_char` (`charidentifier`)
);

-- Optional: auto-remove a lawyer row when its character is deleted. Only enable
-- this if your `characters` table uses InnoDB and `charidentifier` is its PK.
-- ALTER TABLE `doj_lawyers`
--   ADD CONSTRAINT `fk_doj_lawyers_char`
--   FOREIGN KEY (`charidentifier`) REFERENCES `characters` (`charidentifier`)
--   ON DELETE CASCADE;
