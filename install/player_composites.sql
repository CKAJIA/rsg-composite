CREATE TABLE IF NOT EXISTS `player_composites` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `pointkey` VARCHAR(32) NOT NULL,
  `scenario` BIGINT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_citizen_point` (`citizenid`, `pointkey`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;