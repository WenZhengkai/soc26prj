class i2s_transaction extends uvm_sequence_item;
    rand bit [15:0] data;
    rand bit [3:0]  channel; // Assuming a maximum of 16 channels

    constraint valid_channel {
        channel < 16; // Ensure channel number is within valid range
    }