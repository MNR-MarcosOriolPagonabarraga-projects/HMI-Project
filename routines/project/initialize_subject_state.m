function subject_state = initialize_subject_state(num_classes)
    subject_state = struct();
    subject_state.masks = cell(1, num_classes);
    subject_state.rejection_details = cell(1, num_classes);
    subject_state.cz_epochs = cell(1, num_classes);
end
