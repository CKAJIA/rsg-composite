-- ----------------------------
-- Table structure for player_composites
-- ----------------------------
DROP TABLE IF EXISTS `player_composites`;
CREATE TABLE `player_composites`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `pointcoords` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `scenario` bigint(20) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `citizenid`(`citizenid`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 10 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = COMPACT;

