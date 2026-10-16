//
//  JustDewWatchBundle.swift
//  JustDewWatch
//
//  Created by George Babichev on 5/18/26.
//

import WidgetKit
import SwiftUI

@main
struct JustDewWatchBundle: WidgetBundle {
    var body: some Widget {
        JustDewWatch()
        LocationDewPointWatchWidget()
        WeatherWatchWidget()
        LocationWeatherWatchWidget()
    }
}
