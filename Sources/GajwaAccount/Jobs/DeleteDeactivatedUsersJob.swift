//
//  DeleteDeactivatedUsersJob.swift
//  GajwaAccount
//
//  Created by Js Na on 2026/02/02.
//  Copyright © 2026 Js Na. All rights reserved.
//

import Vapor
import Queues
import Fluent

struct DeleteDeactivatedUsersJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        // 7일 전 날짜 계산
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        // 7일이 지난 탈퇴 계정 조회
        let deactivatedUsers = try await User.query(on: context.application.db)
            .filter(\.$userDeactivateDate != nil)
            .filter(\.$userDeactivateDate <= sevenDaysAgo)
            .all()
        
        // 계정 삭제
        for user in deactivatedUsers {
            context.logger.info("비활성화 7일 지난 계정 제거: \(user.userLoginID)")
            try await user.delete(on: context.application.db)
        }
        
        if !deactivatedUsers.isEmpty {
            context.logger.info("\(deactivatedUsers.count)개의 계정을 제거했습니다.")
        }
    }
}
