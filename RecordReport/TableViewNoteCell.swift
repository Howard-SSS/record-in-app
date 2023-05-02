//
//  TableViewNoteCell.swift
//  RecordReport
//
//  Created by Howard-Zjun on 2023/5/2.
//

import UIKit

class TableViewNoteCell: UITableViewCell {

    static var identify: Notification.Name {
        .init(NSStringFromClass(TableViewNoteCell.self))
    }
    
    // MARK: - life time / override
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
