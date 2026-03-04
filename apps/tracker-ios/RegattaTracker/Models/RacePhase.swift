// RacePhase.swift
import Foundation

enum RacePhase: String, Codable {
    case idle       = "IDLE"
    case warming    = "WARNING"
    case prep       = "PREP"
    case oneMinute  = "ONE_MINUTE"
    case racing     = "RACING"
    case postponed  = "POSTPONED"
    case abandoned  = "ABANDONED"
}
